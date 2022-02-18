defmodule Modbus.Model.Shared do
  @moduledoc false
  alias Modbus.Model

  def start_link(opts) do
    model = Keyword.fetch!(opts, :model)
    Agent.start_link(fn -> model end)
  end

  def stop(pid) do
    Agent.stop(pid)
  end

  def state(pid) do
    Agent.get(pid, fn model -> model end)
  end

  def apply(pid, cmd) do
    Agent.get_and_update(pid, fn model ->
      case Model.apply(model, cmd) do
        {:ok, nmodel, values} ->
          {{:ok, values}, nmodel}

        {:ok, nmodel} ->
          {:ok, nmodel}

        {:error, nmodel} ->
          {:error, nmodel}
      end
    end)
  end
end
