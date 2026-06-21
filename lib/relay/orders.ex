defmodule Relay.Orders do
  @moduledoc """
  Transactional command boundary for the order aggregate.

  Every write is tenant-scoped, idempotent, audited, and coupled to durable
  background work in one PostgreSQL transaction.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Relay.Accounts.Organization
  alias Relay.Orders.{IdempotencyKey, Order, OrderEvent, StateMachine}
  alias Relay.Repo
  alias Relay.Workers.OrderEventWorker

  @idempotency_ttl_days 7

  def create_order(%Organization{} = organization, attrs, options) do
    key = Keyword.fetch!(options, :idempotency_key)
    correlation_id = Keyword.fetch!(options, :correlation_id)
    request_hash = request_hash({:create_order, attrs})

    case find_idempotent_resource(organization.id, key, request_hash) do
      {:ok, order} ->
        {:ok, order, :replayed}

      :miss ->
        create_order_transaction(organization, attrs, key, request_hash, correlation_id)

      error ->
        error
    end
  end

  def transition_order(
        %Organization{} = organization,
        order_id,
        command,
        options
      )
      when command in [:pay, :pack, :ship, :deliver, :cancel] do
    key = Keyword.fetch!(options, :idempotency_key)
    correlation_id = Keyword.fetch!(options, :correlation_id)
    actor = Keyword.get(options, :actor, "api")
    request_hash = request_hash({:transition_order, order_id, command})

    case find_idempotent_resource(organization.id, key, request_hash) do
      {:ok, order} ->
        {:ok, order, :replayed}

      :miss ->
        transition_transaction(
          organization,
          order_id,
          command,
          key,
          request_hash,
          correlation_id,
          actor
        )

      error ->
        error
    end
  end

  def transition_order(_organization, _order_id, command, _options),
    do: {:error, {:unknown_command, command}}

  def get_order(%Organization{id: organization_id}, id) do
    Repo.one(
      from order in Order,
        where: order.id == ^id and order.organization_id == ^organization_id,
        preload: [:items]
    )
  end

  def list_events(%Organization{id: organization_id}, order_id) do
    Repo.all(
      from event in OrderEvent,
        where:
          event.organization_id == ^organization_id and
            event.order_id == ^order_id,
        order_by: [asc: event.sequence]
    )
  end

  defp create_order_transaction(
         organization,
         attrs,
         key,
         request_hash,
         correlation_id
       ) do
    order_changeset =
      %Order{organization_id: organization.id}
      |> Order.create_changeset(attrs)

    Multi.new()
    |> Multi.insert(:order, order_changeset)
    |> Multi.insert(:event, fn %{order: order} ->
      event_changeset(
        organization,
        order,
        "order.created",
        %{"status" => "pending"},
        correlation_id,
        "api"
      )
    end)
    |> Multi.insert(:job, fn %{event: event} -> event_job(event) end)
    |> Multi.insert(:idempotency, fn %{order: order} ->
      idempotency_changeset(organization, key, request_hash, order)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} ->
        emit_command_telemetry(:create, :ok, order)
        {:ok, Repo.preload(order, :items), :created}

      {:error, :idempotency, changeset, _changes} ->
        resolve_idempotency_conflict(organization.id, key, request_hash, changeset)

      {:error, _operation, reason, _changes} ->
        emit_command_telemetry(:create, :error, nil)
        {:error, reason}
    end
  end

  defp transition_transaction(
         organization,
         order_id,
         command,
         key,
         request_hash,
         correlation_id,
         actor
       ) do
    Multi.new()
    |> Multi.run(:locked_order, fn repo, _changes ->
      query =
        from order in Order,
          where:
            order.id == ^order_id and
              order.organization_id == ^organization.id,
          lock: "FOR UPDATE"

      case repo.one(query) do
        nil -> {:error, :not_found}
        order -> {:ok, order}
      end
    end)
    |> Multi.run(:next_status, fn _repo, %{locked_order: order} ->
      StateMachine.transition(order.status, command)
    end)
    |> Multi.update(:order, fn %{locked_order: order, next_status: next_status} ->
      Order.transition_changeset(order, next_status)
    end)
    |> Multi.insert(:event, fn %{order: order} ->
      event_changeset(
        organization,
        order,
        event_type(command),
        %{
          "status" => Atom.to_string(order.status),
          "command" => Atom.to_string(command)
        },
        correlation_id,
        actor
      )
    end)
    |> Multi.insert(:job, fn %{event: event} -> event_job(event) end)
    |> Multi.insert(:idempotency, fn %{order: order} ->
      idempotency_changeset(organization, key, request_hash, order)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} ->
        emit_command_telemetry(command, :ok, order)
        {:ok, Repo.preload(order, :items), :updated}

      {:error, :idempotency, changeset, _changes} ->
        resolve_idempotency_conflict(organization.id, key, request_hash, changeset)

      {:error, _operation, reason, _changes} ->
        emit_command_telemetry(command, :error, nil)
        {:error, reason}
    end
  end

  defp event_changeset(
         organization,
         order,
         event_type,
         data,
         correlation_id,
         actor
       ) do
    OrderEvent.changeset(%OrderEvent{}, %{
      organization_id: organization.id,
      order_id: order.id,
      sequence: order.version,
      event_type: event_type,
      data: data,
      actor: actor,
      correlation_id: correlation_id
    })
  end

  defp event_job(event) do
    OrderEventWorker.new(%{
      event_id: event.id,
      event_type: event.event_type,
      order_id: event.order_id,
      organization_id: event.organization_id
    })
  end

  defp event_type(:pay), do: "order.paid"
  defp event_type(:pack), do: "order.packed"
  defp event_type(:ship), do: "order.shipped"
  defp event_type(:deliver), do: "order.delivered"
  defp event_type(:cancel), do: "order.cancelled"

  defp idempotency_changeset(organization, key, request_hash, order) do
    IdempotencyKey.changeset(%IdempotencyKey{}, %{
      organization_id: organization.id,
      key: key,
      request_hash: request_hash,
      resource_type: "order",
      resource_id: order.id,
      expires_at:
        DateTime.utc_now()
        |> DateTime.add(@idempotency_ttl_days, :day)
    })
  end

  defp find_idempotent_resource(organization_id, key, request_hash) do
    query =
      from record in IdempotencyKey,
        where:
          record.organization_id == ^organization_id and
            record.key == ^key and
            record.expires_at > ^DateTime.utc_now()

    case Repo.one(query) do
      nil ->
        :miss

      %{request_hash: ^request_hash, resource_id: resource_id} ->
        case Repo.get(Order, resource_id) do
          nil -> :miss
          order -> {:ok, Repo.preload(order, :items)}
        end

      _record ->
        {:error, :idempotency_key_reused}
    end
  end

  defp resolve_idempotency_conflict(
         organization_id,
         key,
         request_hash,
         _changeset
       ) do
    case find_idempotent_resource(organization_id, key, request_hash) do
      {:ok, order} -> {:ok, order, :replayed}
      :miss -> {:error, :concurrent_request}
      error -> error
    end
  end

  defp request_hash(term) do
    term
    |> canonicalize()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonicalize(value) when is_map(value) do
    value
    |> Enum.map(fn {key, nested} -> {to_string(key), canonicalize(nested)} end)
    |> Enum.sort()
  end

  defp canonicalize(value) when is_list(value), do: Enum.map(value, &canonicalize/1)
  defp canonicalize(value), do: value

  defp emit_command_telemetry(command, result, order) do
    :telemetry.execute(
      [:relay, :orders, :command],
      %{count: 1},
      %{
        command: command,
        result: result,
        status: order && order.status
      }
    )
  end
end
