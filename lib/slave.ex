defmodule Modbus.Slave do
  @moduledoc false
  use GenServer
  alias Modbus.Transport
  alias Modbus.Protocol
  alias Modbus.Shared

  def start_link(opts) do
    ip = Keyword.get(opts, :ip, {127, 0, 0, 1})
    port = Keyword.get(opts, :port, 0)
    model = Keyword.fetch!(opts, :model)
    proto = Keyword.get(opts, :proto, :tcp)
    transm = Transport.module(:tcp)
    protom = Protocol.module(proto)
    init = %{trans: transm, proto: protom, model: model, port: port, ip: ip}
    GenServer.start_link(__MODULE__, init)
  end

  def init(init) do
    {:ok, shared} = Shared.start_link(init.model)
    opts = [:binary, ip: init.ip, packet: :raw, active: false]

    case :gen_tcp.listen(init.port, opts) do
      {:ok, listener} ->
        {:ok, {ip, port}} = :inet.sockname(listener)

        init = Map.put(init, :ip, ip)
        init = Map.put(init, :port, port)
        init = Map.put(init, :shared, shared)
        init = Map.put(init, :listener, listener)

        spawn_link(fn -> accept(init) end)

        {:ok, init}

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

  defp accept(%{shared: shared, proto: proto} = state) do
    case :gen_tcp.accept(state.listener) do
      {:ok, socket} ->
        trans = {state.trans, socket}
        spawn(fn -> client(shared, trans, proto) end)
        accept(state)

      {:error, reason} ->
        Process.exit(self(), reason)
    end
  end

  def client(shared, trans, proto) do
    case Transport.read(trans, 0, -1) do
      {:ok, data} ->
        {cmd, tid} = Protocol.parse_req(proto, data)

        case Shared.apply(shared, cmd) do
          :ok ->
            resp = Protocol.pack_res(proto, cmd, nil, tid)
            Transport.write(trans, resp)

          {:ok, values} ->
            resp = Protocol.pack_res(proto, cmd, values, tid)
            Transport.write(trans, resp)

          _ ->
            :ignore
        end

        client(shared, trans, proto)

      {:error, reason} ->
        Process.exit(self(), reason)
    end
  end
end
