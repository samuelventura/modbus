defmodule Modbus.Request do
  @moduledoc false
  alias Modbus.Utils

  def pack({:rc, slave, address, count}) do
    reads(:d, slave, 1, address, count)
  end

  def pack({:ri, slave, address, count}) do
    reads(:d, slave, 2, address, count)
  end

  def pack({:rhr, slave, address, count}) do
    reads(:a, slave, 3, address, count)
  end

  def pack({:rir, slave, address, count}) do
    reads(:a, slave, 4, address, count)
  end

  def pack({:fc, slave, address, value}) when is_integer(value) do
    write(:d, slave, 5, address, value)
  end

  def pack({:phr, slave, address, value}) when is_integer(value) do
    write(:a, slave, 6, address, value)
  end

  def pack({:fc, slave, address, values}) when is_list(values) do
    writes(:d, slave, 15, address, values)
  end

  def pack({:phr, slave, address, values}) when is_list(values) do
    writes(:a, slave, 16, address, values)
  end

  def parse(<<slave, 1, address::16, count::16>>) do
    {:rc, slave, address, count}
  end

  def parse(<<slave, 2, address::16, count::16>>) do
    {:ri, slave, address, count}
  end

  def parse(<<slave, 3, address::16, count::16>>) do
    {:rhr, slave, address, count}
  end

  def parse(<<slave, 4, address::16, count::16>>) do
    {:rir, slave, address, count}
  end

  def parse(<<slave, 5, address::16, 0x00, 0x00>>) do
    {:fc, slave, address, 0}
  end

  def parse(<<slave, 5, address::16, 0xFF, 0x00>>) do
    {:fc, slave, address, 1}
  end

  def parse(<<slave, 6, address::16, value::16>>) do
    {:phr, slave, address, value}
  end

  def parse(<<slave, 15, address::16, count::16, bytes, data::binary>>) do
    ^bytes = Utils.byte_count(count)
    values = Utils.bin_to_bitlist(count, data)
    {:fc, slave, address, values}
  end

  def parse(<<slave, 16, address::16, count::16, bytes, data::binary>>) do
    ^bytes = 2 * count
    values = Utils.bin_to_reglist(count, data)
    {:phr, slave, address, values}
  end

  def length({:rc, _slave, _address, _count}) do
    6
  end

  def length({:ri, _slave, _address, _count}) do
    6
  end

  def length({:rhr, _slave, _address, _count}) do
    6
  end

  def length({:rir, _slave, _address, _count}) do
    6
  end

  def length({:fc, _slave, _address, value}) when is_integer(value) do
    6
  end

  def length({:phr, _slave, _address, value}) when is_integer(value) do
    6
  end

  def length({:fc, _slave, _address, values}) when is_list(values) do
    7 + Utils.byte_count(Enum.count(values))
  end

  def length({:phr, _slave, _address, values}) when is_list(values) do
    7 + 2 * Enum.count(values)
  end

  defp reads(_type, slave, function, address, count) do
    <<slave, function, address::16, count::16>>
  end

  defp write(:d, slave, function, address, value) do
    <<slave, function, address::16, Utils.bool_to_byte(value), 0x00>>
  end

  defp write(:a, slave, function, address, value) do
    <<slave, function, address::16, value::16>>
  end

  defp writes(:d, slave, function, address, values) do
    count = Enum.count(values)
    bytes = Utils.byte_count(count)
    data = Utils.bitlist_to_bin(values)
    <<slave, function, address::16, count::16, bytes, data::binary>>
  end

  defp writes(:a, slave, function, address, values) do
    count = Enum.count(values)
    bytes = 2 * count
    data = Utils.reglist_to_bin(values)
    <<slave, function, address::16, count::16, bytes, data::binary>>
  end
end
