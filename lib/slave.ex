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
    owner = self()

    case :gen_tcp.listen(port, opts) do
      {:ok, listener} ->
        spawn_link(fn -> accept(owner, listener, shared) end)
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

  def stop(pid) do
    GenServer.stop(pid)
  end

  def port(pid) do
    GenServer.call(pid, :port)
  end

  def handle_call(:port, _from, state) do
    {:reply, state.port, state}
  end

  def handle_info({:closed, reason}, state) do
    {:stop, reason, state}
  end

  defp accept(owner, listener, shared) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        pid = start_child(socket, shared)
        :ok = :gen_tcp.controlling_process(socket, pid)
        send(pid, :go)
        accept(owner, listener, shared)

      {:error, reason} ->
        send(owner, {:closed, reason})
    end
  end

  def start_child(socket, shared) do
    spawn(fn ->
      receive do
        :go -> loop(socket, shared)
      end
    end)
  end

  defp loop(socket, shared) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        {cmd, transid} = Tcp.parse_req(data)
        result = Shared.apply(shared, cmd)

        case result do
          :ok ->
            resp = Tcp.pack_res(cmd, nil, transid)
            :ok = :gen_tcp.send(socket, resp)
            loop(socket, shared)

          {:ok, values} ->
            resp = Tcp.pack_res(cmd, values, transid)
            :ok = :gen_tcp.send(socket, resp)
            loop(socket, shared)

          other ->
            other
        end

      other ->
        other
    end
  end
end
