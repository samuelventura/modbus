defmodule RequestTest do
  use ExUnit.Case
  alias Modbus.Request

  test "Request pack and parse test" do
    pp <<0x22, 0x01, 0x23, 0x24, 0x25, 0x26>>, {:rc, 0x22, 0x2324, 0x2526}
    pp <<0x22, 0x02, 0x23, 0x24, 0x25, 0x26>>, {:ri, 0x22, 0x2324, 0x2526}
    pp <<0x22, 0x03, 0x23, 0x24, 0x25, 0x26>>, {:rhr, 0x22, 0x2324, 0x2526}
    pp <<0x22, 0x04, 0x23, 0x24, 0x25, 0x26>>, {:rir, 0x22, 0x2324, 0x2526}
    pp <<0x22, 0x05, 0x23, 0x24, 0x00, 0x00>>, {:fc, 0x22, 0x2324, 0}
    pp <<0x22, 0x05, 0x23, 0x24, 0xFF, 0x00>>, {:fc, 0x22, 0x2324, 1}
    pp <<0x22, 0x06, 0x23, 0x24, 0x25, 0x26>>, {:phr, 0x22, 0x2324, 0x2526}
    pp <<0x22, 0x0F, 0x23, 0x24, 0x00, 0x01, 0x01, 0x00>>, {:fc, 0x22, 0x2324, [0]}
    pp <<0x22, 0x0F, 0x23, 0x24, 0x00, 0x01, 0x01, 0x01>>, {:fc, 0x22, 0x2324, [1]}
    pp <<0x22, 0x10, 0x23, 0x24, 0x00, 0x01, 0x02, 0x25, 0x26>>, {:phr, 0x22, 0x2324, [0x2526]}
    #corner cases
    pp <<0x22, 0x0F, 0x23, 0x24, 0x00, 0x08, 0x01, 0x96>>, {:fc, 0x22, 0x2324, [0,1,1,0, 1,0,0,1]}
    pp <<0x22, 0x0F, 0x23, 0x24, 0x00, 0x09, 0x02, 0x96, 0x01>>, {:fc, 0x22, 0x2324, [0,1,1,0, 1,0,0,1, 1]}
    pp <<0x22, 0x0F, 0x23, 0x24, 0x00, 0x10, 0x02, 0x96, 0xC3>>, {:fc, 0x22, 0x2324, [0,1,1,0, 1,0,0,1, 1,1,0,0, 0,0,1,1]}
    pp <<0x22, 0x0F, 0x23, 0x24, 0x00, 0x11, 0x03, 0x96, 0xC3, 0x01>>, {:fc, 0x22, 0x2324, [0,1,1,0, 1,0,0,1, 1,1,0,0, 0,0,1,1, 1]}
    pp <<0x22, 0x0F, 0x23, 0x24, 0x07, 0xF8, 0xFF>> <> l2b1(bls(2040)), {:fc, 0x22, 0x2324, bls(2040)}
    pp <<0x22, 0x10, 0x23, 0x24, 0x00, 0x7F, 0xFE>> <> l2b16(rls(127)), {:phr, 0x22, 0x2324, rls(127)}
    #invalid cases
    assert <<0x22, 0x0F, 0x23, 0x24, 0x07, 0xF9, 0x00>> <> l2b1(bls(2041)) == Request.pack({:fc, 0x22, 0x2324, bls(2041)})
    assert <<0x22, 0x10, 0x23, 0x24, 0x00, 0x80, 0x00>> <> l2b16(rls(128)) == Request.pack({:phr, 0x22, 0x2324, rls(128)})
  end

  defp pp(packet, cmd) do
    assert packet == Request.pack(cmd)
    assert cmd == Request.parse(packet)
  end

  defp bls(size) do
    for i <- 1..size do
      rem(i, 2)
    end
  end

  defp rls(size) do
    for i <- 1..size do
      i
    end
  end

  defp l2b1(list) do
    lists = Enum.chunk(list, 8, 8, [0, 0, 0, 0, 0, 0, 0, 0])
    list = for [v0, v1, v2, v3, v4, v5, v6, v7] <- lists do
      << v7::1, v6::1, v5::1, v4::1, v3::1, v2::1, v1::1, v0::1 >>
    end
    :erlang.iolist_to_binary(list)
  end

  defp l2b16(list) do
    list2 = for i <- list do
      <<i::16>>
    end
    :erlang.iolist_to_binary(list2)
  end

end
