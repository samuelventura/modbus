defmodule Modbus.Model do
  @moduledoc false

  def apply(state, {:rc, slave, address, count}) do
    reads(state, {slave, :c, address, count})
  end

  def apply(state, {:ri, slave, address, count}) do
    reads(state, {slave, :i, address, count})
  end

  def apply(state, {:rhr, slave, address, count}) do
    reads(state, {slave, :hr, address, count})
  end

  def apply(state, {:rir, slave, address, count}) do
    reads(state, {slave, :ir, address, count})
  end

  def apply(state, {:fc, slave, address, value}) when is_integer(value) do
    write(state, {slave, :c, address, value})
  end

  def apply(state, {:fc, slave, address, values}) when is_list(values) do
    writes(state, {slave, :c, address, values})
  end

  def apply(state, {:phr, slave, address, value}) when is_integer(value) do
    write(state, {slave, :hr, address, value})
  end

  def apply(state, {:phr, slave, address, values}) when is_list(values) do
    writes(state, {slave, :hr, address, values})
  end

  defp reads(state, {slave, type, address, count}) do
    case check_request(state, {slave, type, address, count}) do
      true ->
        map = Map.fetch!(state, slave)

        list =
          for point <- address..(address + count - 1) do
            Map.fetch!(map, {type, point})
          end

        {state, list}

      false ->
        {state, :error}
    end
  end

  defp write(state, {slave, type, address, value}) do
    cmap = Map.fetch!(state, slave)
    nmap = Map.put(cmap, {type, address}, value)
    {Map.put(state, slave, nmap), nil}
  end

  defp writes(state, {slave, type, address, values}) do
    cmap = Map.fetch!(state, slave)
    final = address + Enum.count(values)

    {^final, nmap} =
      Enum.reduce(values, {address, cmap}, fn value, {i, map} ->
        {i + 1, Map.put(map, {type, i}, value)}
      end)

    {Map.put(state, slave, nmap), nil}
  end

  def check_request(state, {slave, type, addr, count}) do
    map = Map.get(state, slave)

    case map do
      nil ->
        false

      _ ->
        addr_end = addr + count - 1

        Enum.all?(addr..addr_end, fn addr ->
          Map.has_key?(map, {type, addr})
        end)
    end
  end
end
