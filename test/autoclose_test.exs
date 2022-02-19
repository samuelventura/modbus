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
        {:ok, mpid} = Master.connect(ip: {127, 0, 0, 1}, port: port)
        IO.inspect({mpid, Process.info(self())})
        send(self, mpid)
      end)

    ref = :erlang.monitor(:process, pid)
    assert_receive mpid, 400
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 800
    :timer.sleep(200)
    assert {:error, :closed} == :gen_tcp.recv(mpid.socket, 0, 0)
    0 = Agent.get(mpid.agent, fn tid -> tid end)
    assert false == Process.alive?(mpid.agent)
  end
end
