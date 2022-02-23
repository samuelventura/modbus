defmodule Modbus.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Modbus.Registry, []}
    ]

    opts = [strategy: :one_for_one, name: Modbus.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
