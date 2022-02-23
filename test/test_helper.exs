ExUnit.start()

defmodule Modbus.TestHelper do
  use ExUnit.Case
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Model
  alias Modbus.Master
  alias Modbus.Slave
  alias Modbus.Rtu
  alias Modbus.Tcp

  def pp1(cmd, req, res, val, model) do
    assert req == Request.pack(cmd)
    assert cmd == Request.parse(req)
    assert {:ok, model, val} == Model.apply(model, cmd)
    assert res == Response.pack(cmd, val)
    assert val == Response.parse(cmd, res)
    # length prediction
    assert byte_size(res) == Response.length(cmd)
    assert byte_size(req) == Request.length(cmd)
    # rtu
    rtu_req = Rtu.Protocol.pack_req(cmd)
    assert {cmd, nil} == Rtu.Protocol.parse_req(rtu_req)
    rtu_res = Rtu.Protocol.pack_res(cmd, val)
    assert val == Rtu.Protocol.parse_res(cmd, rtu_res)
    assert byte_size(rtu_res) == Rtu.Protocol.res_len(cmd)
    # tcp
    tcp_req = Tcp.Protocol.pack_req(cmd, 1)
    assert {cmd, 1} == Tcp.Protocol.parse_req(tcp_req)
    tcp_res = Tcp.Protocol.pack_res(cmd, val, 1)
    assert val == Tcp.Protocol.parse_res(cmd, tcp_res, 1)
    assert byte_size(tcp_res) == Tcp.Protocol.res_len(cmd)
    # master
    {:ok, slave_pid} = Slave.start_link(model: model)
    port = Slave.port(slave_pid)
    {:ok, master_pid} = Master.open(port: port, ip: {127, 0, 0, 1})

    for _ <- 0..10 do
      assert {:ok, val} == Master.exec(master_pid, cmd)
    end
  end

  def pp2(cmd, req, res, model0, model1) do
    assert req == Request.pack(cmd)
    assert cmd == Request.parse(req)
    assert {:ok, model1} == Model.apply(model0, cmd)
    assert res == Response.pack(cmd, nil)
    assert nil == Response.parse(cmd, res)
    # length prediction
    assert byte_size(res) == Response.length(cmd)
    # rtu
    rtu_req = Rtu.Protocol.pack_req(cmd)
    assert {cmd, nil} == Rtu.Protocol.parse_req(rtu_req)
    rtu_res = Rtu.Protocol.pack_res(cmd, nil)
    assert nil == Rtu.Protocol.parse_res(cmd, rtu_res)
    assert byte_size(rtu_res) == Rtu.Protocol.res_len(cmd)
    # tcp
    tcp_req = Tcp.Protocol.pack_req(cmd, 1)
    assert {cmd, 1} == Tcp.Protocol.parse_req(tcp_req)
    tcp_res = Tcp.Protocol.pack_res(cmd, nil, 1)
    assert nil == Tcp.Protocol.parse_res(cmd, tcp_res, 1)
    assert byte_size(tcp_res) == Tcp.Protocol.res_len(cmd)
    # master
    {:ok, slave_pid} = Slave.start_link(model: model0)
    port = Slave.port(slave_pid)
    {:ok, master_pid} = Master.open(port: port, ip: {127, 0, 0, 1})

    for _ <- 0..10 do
      assert :ok == Master.exec(master_pid, cmd)
    end
  end
end
