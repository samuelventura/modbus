defmodule Modbus.Shared do
  @moduledoc false
  alias Modbus.Model

  def start_link(model) do
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
      try do
        case Model.apply(model, cmd) do
          {:ok, nmodel, values} ->
            {{:ok, values}, nmodel}

          {:ok, nmodel} ->
            {:ok, nmodel}

          {:error, nmodel} ->
            {{:error, {:invalid, cmd}}, nmodel}
        end
      rescue
        _ -> {{:error, {:invalid, cmd}}, model}
      end
    end)
  end
end
