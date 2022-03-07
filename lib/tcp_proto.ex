defmodule Modbus.Tcp.Protocol do
  @moduledoc false
  @behaviour Modbus.Protocol
  alias __MODULE__.Wrapper
  alias Modbus.Request
  alias Modbus.Response
  import Bitwise

  def next(tid) do
    case tid do
      nil -> 0
      _ -> band(tid + 1, 0xFFFF)
    end
  end

  def pack_req(cmd, tid) do
    cmd |> Request.pack() |> Wrapper.wrap(tid)
  end

  def res_len(cmd) do
    Response.length(cmd) + 6
  end

  def parse_res(cmd, wraped, tid) do
    Response.parse(cmd, wraped |> Wrapper.unwrap(tid))
  end

  def parse_req(wraped) do
    {pack, transid} = wraped |> Wrapper.unwrap()
    {pack |> Request.parse(), transid}
  end

  def pack_res(cmd, values, tid) do
    cmd |> Response.pack(values) |> Wrapper.wrap(tid)
  end

  defmodule Wrapper do
    @moduledoc false
    def wrap(payload, tid) do
      size = :erlang.byte_size(payload)
      <<tid::16, 0, 0, size::16, payload::binary>>
    end

    def unwrap(<<tid::16, 0, 0, size::16, payload::binary>>, tid) do
      ^size = :erlang.byte_size(payload)
      payload
    end

    def unwrap(<<tid::16, 0, 0, size::16, payload::binary>>) do
      ^size = :erlang.byte_size(payload)
      {payload, tid}
    end
  end
end
