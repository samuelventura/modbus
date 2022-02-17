defmodule Modbus.Tcp.Slave do
  @moduledoc false
  alias Modbus.Model.Shared
  alias Modbus.Tcp

  def start_link(params, opts \\ []) do
    Agent.start_link(fn -> init(params) end, opts)
  end

  def stop(pid) do
    Agent.stop(pid)
  end

  # comply with formward id
  def id(pid) do
    case state(pid) do
      {:error, reason} ->
        {:error, reason}

      _ ->
        Agent.get(pid, fn %{ip: ip, port: port} ->
          {:ok, %{ip: ip, port: port}}
        end)
    end
  end

  def state(pid) do
    Agent.get(pid, fn state -> state end)
  end

  defp init(params) do
    model = Keyword.fetch!(params, :model)
    {:ok, shared} = Shared.start_link(model: model)
    port = Keyword.get(params, :port, 0)

    case :gen_tcp.listen(port, [:binary, packet: :raw, active: false]) do
      {:ok, listener} ->
        {:ok, {ip, port}} = :inet.sockname(listener)
        accept = spawn_link(fn -> accept(listener, shared) end)

        %{
          ip: ip,
          port: port,
          shared: shared,
          accept: accept,
          listener: listener
        }

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp accept(listener, model) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        pid = start_child(socket, model)
        :ok = :gen_tcp.controlling_process(socket, pid)
        send(pid, :go)
        accept(listener, model)

      other ->
        other
    end
  end

  def start_child(socket, shared) do
    spawn(fn ->
      receive do
        :go ->
          loop(socket, shared)
      end
    end)
  end

  defp loop(socket, shared) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        {cmd, transid} = Tcp.parse_req(data)

        case Shared.apply(shared, cmd) do
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
