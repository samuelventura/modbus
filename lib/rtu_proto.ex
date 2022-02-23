defmodule Modbus.Rtu.Protocol do
  @moduledoc false
  @behaviour Modbus.Protocol
  alias __MODULE__.Wrapper
  alias Modbus.Request
  alias Modbus.Response
  alias Modbus.Crc

  def next(_) do
  end

  def pack_req(cmd, _tid \\ nil) do
    cmd |> Request.pack() |> Wrapper.wrap()
  end

  def res_len(cmd) do
    Response.length(cmd) + 2
  end

  def parse_res(cmd, wraped, _tid \\ nil) do
    Response.parse(cmd, wraped |> Wrapper.unwrap())
  end

  def parse_req(wraped) do
    {wraped |> Wrapper.unwrap() |> Request.parse(), nil}
  end

  def pack_res(cmd, values, _tid \\ nil) do
    cmd |> Response.pack(values) |> Wrapper.wrap()
  end

  defmodule Wrapper do
    @moduledoc false
    # CRC is little endian
    # http://modbus.org/docs/Modbus_over_serial_line_V1_02.pdf page 13
    def wrap(payload) do
      <<crc_hi, crc_lo>> = Crc.crc(payload)
      <<payload::binary, crc_lo, crc_hi>>
    end

    # CRC is little endian
    # http://modbus.org/docs/Modbus_over_serial_line_V1_02.pdf page 13
    def unwrap(data) do
      size = :erlang.byte_size(data) - 2
      <<payload::binary-size(size), crc_lo, crc_hi>> = data
      <<^crc_hi, ^crc_lo>> = Crc.crc(payload)
      payload
    end
  end
end
