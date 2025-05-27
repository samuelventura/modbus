defmodule Modbus.Utils do
  @moduledoc false

  def byte_count(count) do
    div(count - 1, 8) + 1
  end

  def bool_to_byte(value) do
    # enforce 0 or 1 only
    case value do
      0 -> 0x00
      1 -> 0xFF
    end
  end

  def bin_to_bitlist(count, <<b7::1, b6::1, b5::1, b4::1, b3::1, b2::1, b1::1, b0::1>>)
      when count <= 8 do
    Enum.take([b0, b1, b2, b3, b4, b5, b6, b7], count)
  end

  def bin_to_bitlist(
        count,
        <<b7::1, b6::1, b5::1, b4::1, b3::1, b2::1, b1::1, b0::1, tail::binary>>
      ) do
    [b0, b1, b2, b3, b4, b5, b6, b7] ++ bin_to_bitlist(count - 8, tail)
  end

  def bin_to_reglist(1, <<register::16>>) do
    [register]
  end

  def bin_to_reglist(count, <<register::16, tail::binary>>) do
    [register | bin_to_reglist(count - 1, tail)]
  end

  def bitlist_to_bin(values) do
    lists = Enum.chunk_every(values, 8, 8, [0, 0, 0, 0, 0, 0, 0, 0])

    list =
      for list8 <- lists do
        [v0, v1, v2, v3, v4, v5, v6, v7] =
          for b <- list8 do
            # enforce 0 or 1 only
            bool_to_byte(b)
          end

        <<v7::1, v6::1, v5::1, v4::1, v3::1, v2::1, v1::1, v0::1>>
      end

    :erlang.iolist_to_binary(list)
  end

  def reglist_to_bin(values) do
    list =
      for value <- values do
        <<value::size(16)>>
      end

    :erlang.iolist_to_binary(list)
  end
end
