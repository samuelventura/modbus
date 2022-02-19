defmodule Modbus.RescueTest do
  use ExUnit.Case
  @state %{0x50 => %{{:c, 0x5152} => 0}}

  test "shared model wont die on invalid command" do
    alias Modbus.Model.Shared
    {:ok, pid} = Shared.start_link(@state)
    {:error, {:invalid, :command}} = Shared.apply(pid, :command)
    :ok = Shared.apply(pid, {:fc, 0x50, 0x5152, 0})
    {:ok, [0]} = Shared.apply(pid, {:rc, 0x50, 0x5152, 1})
    :ok = Shared.apply(pid, {:fc, 0x50, 0x5152, 1})
    {:ok, [1]} = Shared.apply(pid, {:rc, 0x50, 0x5152, 1})
  end

  test "master and slave wont die on invalid command" do
    alias Modbus.Tcp.Slave
    alias Modbus.Tcp.Master
    {:ok, spid} = Slave.start_link(model: @state)
    port = Slave.port(spid)
    {:ok, pid} = Master.start_link(ip: {127, 0, 0, 1}, port: port)
    {:error, {:invalid, {:cmd, 0}}} = Master.exec(pid, {:cmd, 0})
    :ok = Master.exec(pid, {:fc, 0x50, 0x5152, 0})
    {:ok, [0]} = Master.exec(pid, {:rc, 0x50, 0x5152, 1})
    :ok = Master.exec(pid, {:fc, 0x50, 0x5152, 1})
    {:ok, [1]} = Master.exec(pid, {:rc, 0x50, 0x5152, 1})
  end
end
