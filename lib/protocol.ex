defmodule Modbus.Protocol do
  @moduledoc false
  @callback next(tid :: any()) :: any()
  @callback pack_req(cmd :: tuple(), tid :: any) :: req :: binary()
  @callback res_len(cmd :: tuple()) :: len :: integer()
  @callback parse_res(cmd :: tuple(), res :: binary(), tid :: any) :: list(integer())
  @callback parse_req(req :: binary()) :: {cmd :: tuple(), tid :: any}
  @callback pack_res(cmd :: tuple(), values :: list(integer()), tid :: any) :: req :: binary()

  def next(mod, tid) do
    mod.next(tid)
  end

  def pack_req(mod, cmd, tid) do
    mod.pack_req(cmd, tid)
  end

  def res_len(mod, cmd) do
    mod.res_len(cmd)
  end

  def parse_res(mod, cmd, res, tid) do
    mod.parse_res(cmd, res, tid)
  end

  def parse_req(mod, req) do
    mod.parse_req(req)
  end

  def pack_res(mod, cmd, values, tid) do
    mod.pack_res(cmd, values, tid)
  end
end
