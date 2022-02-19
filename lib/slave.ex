defmodule Modbus.Tcp.Slave do
  use GenServer
  @moduledoc false
  alias Modbus.Model.Shared
  alias Modbus.Tcp

  def start_link(opts) do
    ip = Keyword.get(opts, :ip, {127, 0, 0, 1})
    port = Keyword.get(opts, :port, 0)
    model = Keyword.fetch!(opts, :model)
    GenServer.start_link(__MODULE__, {ip, port, model})
  end

  def init({ip, port, model}) do
    {:ok, shared} = Shared.start_link(model)
    opts = [:binary, ip: ip, packet: :raw, active: false]

    case :gen_tcp.listen(port, opts) do
      {:ok, listener} ->
        spawn_link(fn -> accept(listener, shared) end)
        {:ok, {ip, port}} = :inet.sockname(listener)

        {:ok,
         %{
           ip: ip,
           port: port,
           shared: shared,
           listener: listener
         }}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  def terminate(reason, %{shared: shared}) do
    Agent.stop(shared, reason)
  end

  def stop(pid) do
    # listener automatic close should
    # close the accepting process which
    # should close all client sockets
    GenServer.stop(pid)
  end

  def port(pid) do
    GenServer.call(pid, :port)
  end

  def handle_call(:port, _from, state) do
    {:reply, state.port, state}
  end

  defp accept(listener, shared) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        spawn(fn -> client(socket, shared) end)
        accept(listener, shared)

      error ->
        Process.exit(self(), error)
    end
  end

  def client(socket, shared) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        {cmd, transid} = Tcp.parse_req(data)
        result = Shared.apply(shared, cmd)

        case result do
          :ok ->
            resp = Tcp.pack_res(cmd, nil, transid)
            :gen_tcp.send(socket, resp)

          {:ok, values} ->
            resp = Tcp.pack_res(cmd, values, transid)
            :gen_tcp.send(socket, resp)

          _ ->
            :ignore
        end

        client(socket, shared)

      error ->
        Process.exit(self(), error)
    end
  end
end
