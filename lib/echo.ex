defmodule Modbus.Echo do
  @moduledoc false
  use GenServer

  def start_link(opts \\ []) do
    ip = Keyword.get(opts, :ip, {127, 0, 0, 1})
    port = Keyword.get(opts, :port, 0)
    GenServer.start_link(__MODULE__, {ip, port})
  end

  def init({ip, port}) do
    opts = [:binary, ip: ip, packet: :raw, active: false]

    case :gen_tcp.listen(port, opts) do
      {:ok, listener} ->
        spawn_link(fn -> accept(listener) end)
        {:ok, {ip, port}} = :inet.sockname(listener)

        {:ok,
         %{
           ip: ip,
           port: port,
           listener: listener
         }}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  def stop(pid) do
    # listener automatic close should
    # close the accepting process which
    # should close all client sockets
    GenServer.stop(pid)
  end

  def endpoint(pid) do
    GenServer.call(pid, :endpoint)
  end

  def handle_call(:endpoint, _from, state) do
    {:reply, {state.ip, state.port}, state}
  end

  defp accept(listener) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        spawn(fn -> client(socket) end)
        accept(listener)

      {:error, reason} ->
        Process.exit(self(), reason)
    end
  end

  def client(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        :gen_tcp.send(socket, data)
        client(socket)

      {:error, reason} ->
        Process.exit(self(), reason)
    end
  end
end
