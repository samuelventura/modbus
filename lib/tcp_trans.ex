defmodule Modbus.Tcp.Transport do
  @moduledoc false
  @behaviour Modbus.Transport
  @to 2000

  def open(opts) do
    ip = Keyword.fetch!(opts, :ip)
    port = Keyword.fetch!(opts, :port)
    timeout = Keyword.get(opts, :timeout, @to)
    opts = [:binary, packet: :raw, active: false]
    :gen_tcp.connect(ip, port, opts, timeout)
  end

  def read(socket, count, timeout) do
    timeout =
      case timeout do
        -1 -> :infinity
        _ -> timeout
      end

    :gen_tcp.recv(socket, count, timeout)
  end

  def write(socket, packet) do
    # discard before send
    :gen_tcp.recv(socket, 0, 0)
    :gen_tcp.send(socket, packet)
  end

  def close(socket) do
    :gen_tcp.close(socket)
  end
end
