defmodule Modbus.TcpTest do
  use ExUnit.Case
  alias Modbus.Tcp

  # http://www.tahapaksu.com/crc/
  # https://www.lammertbies.nl/comm/info/crc-calculation.html
  test "wrap test" do
    p(0, <<>>, <<0, 0, 0, 0, 0, 0>>)
    p(1, <<0>>, <<0, 1, 0, 0, 0, 1, 0>>)
    p(2, <<0, 1>>, <<0, 2, 0, 0, 0, 2, 0, 1>>)
    p(3, <<0, 1, 2>>, <<0, 3, 0, 0, 0, 3, 0, 1, 2>>)
    p(4, <<0, 1, 2, 3>>, <<0, 4, 0, 0, 0, 4, 0, 1, 2, 3>>)
  end

  defp p(transid, payload, packet) do
    assert packet == payload |> Tcp.Protocol.Wrapper.wrap(transid)
    assert {payload, transid} == packet |> Tcp.Protocol.Wrapper.unwrap()
  end

  test "transaction id wraps around 0xFFFF" do
    # run with: mix slave
    alias Modbus.Slave
    alias Modbus.Master

    # start your slave with a shared model
    model = %{0x50 => %{{:c, 0x5152} => 0}}

    {:ok, slave} = Slave.start_link(model: model)
    # get the assigned tcp port
    port = Slave.port(slave)

    # interact with it
    {:ok, master} = Master.start_link(ip: {127, 0, 0, 1}, port: port)
    ini = 0xFFF0
    GenServer.call(master, {:update, :tid, ini})

    for tid <- ini..(ini + 0x10) do
      tid = Bitwise.band(tid, 0xFFFF)
      assert tid == GenServer.call(master, {:get, :tid})
      :ok = Master.exec(master, {:fc, 0x50, 0x5152, 0})
    end

    :ok = Master.stop(master)
    :ok = Slave.stop(slave)
  end
end
