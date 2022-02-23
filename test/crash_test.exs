defmodule Modbus.CrashTest do
  use ExUnit.Case

  test "master exists on non normal process exit" do
    alias Modbus.Slave
    alias Modbus.Master

    # start your slave with a shared model
    model = %{0x50 => %{{:c, 0x5152} => 0}}
    {:ok, spid} = Slave.start_link(model: model)
    # get the assigned tcp port
    port = Slave.port(spid)
    self = self()

    pid =
      spawn(fn ->
        {:ok, master} = Master.start_link(ip: {127, 0, 0, 1}, port: port)
        send(self, master)

        receive do
          reason -> Process.exit(self(), reason)
        end
      end)

    # sockets have been tested separately to
    # auto close even on normal process exit
    ref = :erlang.monitor(:process, pid)
    assert_receive master, 400
    send(pid, :crash)
    assert_receive {:DOWN, ^ref, :process, ^pid, :crash}, 400
    # crash required for linked process to exit
    assert false == Process.alive?(master)
  end
end
