defmodule AutoCloseTest do
  use ExUnit.Case

  test "test slave and master interaction" do
    # run with: mix slave
    alias Modbus.Tcp.Slave
    alias Modbus.Tcp.Master

    # start your slave with a shared model
    model = %{0x50 => %{{:c, 0x5152} => 0}}
    {:ok, spid} = Slave.start_link(model: model)
    # get the assigned tcp port
    port = Slave.port(spid)
    self = self()

    pid =
      spawn(fn ->
        {:ok, mpid} = Master.start_link(ip: {127, 0, 0, 1}, port: port)
        socket = GenServer.call(mpid, :socket)
        send(self, {mpid, socket})
        # crash required for linked process to exit as well
        Process.exit(self(), :crash)
      end)

    ref = :erlang.monitor(:process, pid)
    assert_receive {mpid, socket}, 400
    assert_receive {:DOWN, ^ref, :process, ^pid, :crash}, 800
    assert {:error, :closed} == :gen_tcp.recv(socket, 0, 0)
    assert false == Process.alive?(mpid)
  end
end
