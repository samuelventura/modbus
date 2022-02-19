defmodule Modbus.Model do
  @moduledoc false

  def apply(state, {:rc, slave, address, count}) when is_integer(address) and is_integer(count) do
    reads(state, {slave, :c, address, count})
  end

  def apply(state, {:ri, slave, address, count}) when is_integer(address) and is_integer(count) do
    reads(state, {slave, :i, address, count})
  end

  def apply(state, {:rhr, slave, address, count})
      when is_integer(address) and is_integer(count) do
    reads(state, {slave, :hr, address, count})
  end

  def apply(state, {:rir, slave, address, count})
      when is_integer(address) and is_integer(count) do
    reads(state, {slave, :ir, address, count})
  end

  def apply(state, {:fc, slave, address, value})
      when is_integer(address) and not is_list(value) do
    write(state, {slave, :c, address, value})
  end

  def apply(state, {:fc, slave, address, values}) when is_integer(address) and is_list(values) do
    writes(state, {slave, :c, address, values})
  end

  def apply(state, {:phr, slave, address, value})
      when is_integer(address) and not is_list(value) do
    write(state, {slave, :hr, address, value})
  end

  def apply(state, {:phr, slave, address, values}) when is_integer(address) and is_list(values) do
    writes(state, {slave, :hr, address, values})
  end

  defp reads(state, {slave, type, address, count}) do
    case check_request(state, {slave, type, address, count}) do
      true ->
        map = Map.fetch!(state, slave)
        addr_end = address + count - 1

        list =
          for point <- address..addr_end do
            Map.fetch!(map, {type, point})
          end

        {:ok, state, list}

      false ->
        {:error, state}
    end
  end

  defp write(state, {slave, type, address, value}) do
    case check_request(state, {slave, type, address, 1}) do
      true ->
        cmap = Map.fetch!(state, slave)
        nmap = Map.put(cmap, {type, address}, value)
        {:ok, Map.put(state, slave, nmap)}

      false ->
        {:error, state}
    end
  end

  defp writes(state, {slave, type, address, values}) do
    count = length(values)

    case check_request(state, {slave, type, address, count}) do
      true ->
        cmap = Map.fetch!(state, slave)
        addr_end = address + count

        {^addr_end, nmap} =
          Enum.reduce(values, {address, cmap}, fn value, {i, map} ->
            {i + 1, Map.put(map, {type, i}, value)}
          end)

        {:ok, Map.put(state, slave, nmap)}

      false ->
        {:error, state}
    end
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
