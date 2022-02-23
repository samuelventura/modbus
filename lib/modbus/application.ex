defmodule Modbus.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Modbus.Registry, []}
    ]

    opts = [strategy: :one_for_one, name: Modbus.Supervisor]

    try do
      Supervisor.start_link(children, opts)
    after
      Modbus.Registry.register({:trans, :tcp}, Modbus.Tcp.Transport)
      Modbus.Registry.register({:proto, :tcp}, Modbus.Tcp.Protocol)
    end
  end
end
