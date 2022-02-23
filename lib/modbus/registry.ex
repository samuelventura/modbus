defmodule Modbus.Registry do
  @moduledoc false
  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link() do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  def register(key, value) do
    Registry.register(__MODULE__, key, value)
  end

  def lookup!(key) do
    case Registry.lookup(__MODULE__, key) do
      [] -> raise "Registry key not found #{key}"
      [{_, value}] -> value
    end
  end

  def update(key, fun) do
    Registry.update_value(__MODULE__, key, fun)
  end

  def unregister(key) do
    Registry.unregister(__MODULE__, key)
  end
end
