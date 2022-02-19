defmodule EchoTest do
  use ExUnit.Case

  # these tests and the echo server is mostly to
  # grasp socket behaviour on normal process exit
  test "clients are auto closed on echo server stop" do
    {:ok, pid} = Modbus.Echo.start_link()
    opts = [:binary, packet: :raw, active: false]
    {ip, port} = Modbus.Echo.endpoint(pid)
    {:ok, client} = :gen_tcp.connect(ip, port, opts)
    :ok = Modbus.Echo.stop(pid)
    {:error, :econnrefused} = :gen_tcp.connect(ip, port, opts)
    :timer.sleep(100)
    {:ok, {_, _}} = :inet.sockname(client)
    assert :ok == :gen_tcp.send(client, "data")
    # recv seems to be the closed detection mechanism
    assert {:error, :closed} == :gen_tcp.recv(client, 0)
    assert {:error, :closed} == :gen_tcp.send(client, "data")
  end
end
