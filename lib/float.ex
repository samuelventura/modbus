defmodule Modbus.Float do
  @moduledoc """
  IEEE754 float converter

  Based on https://www.h-schmidt.net/FloatConverter/Float.html.
  """

  @doc """
  Converts a list of 2n 16-bit registers to a list of IEEE754 big endian floats.

  ## Example

  ```elixir
  [+5.0] = Float.from_be([0x40a0, 0x0000])
  [-5.0, +5.0] = Float.from_be([0xc0a0, 0x0000, 0x40a0, 0x0000])
  ```
  """
  def from_be(list_of_regs), do: from(list_of_regs, :be)

  @doc """
  Converts a list of 2n 16-bit registers to a list of IEEE754 little endian floats.

  ## Example

  ```elixir
  [+5.0] = Float.from_le([0x0000, 0x40a0])
  [-5.0, +5.0] = Float.from_le([0x0000, 0xc0a0, 0x0000, 0x40a0])
  ```
  """
  def from_le(list_of_regs), do: from(list_of_regs, :le)

  @doc """
  Converts a list of IEEE754 big endian floats to a list of 2n 16-bit registers.

  ## Example

  ```elixir
  [0x40a0, 0x0000] = Float.to_be([+5.0])
  [0xc0a0, 0x0000, 0x40a0, 0x0000] = Float.to_be([-5.0, +5.0])
  ```
  """
  def to_be(list_of_floats), do: to(list_of_floats, :be)

  @doc """
  Converts a list of IEEE754 little endian floats to a list of 2n 16-bit registers.

  ## Example

  ```elixir
  [0x0000, 0x40a0] = Float.to_le([+5.0])
  [0x0000, 0xc0a0, 0x0000, 0x40a0] = Float.to_le([-5.0, +5.0])
  ```
  """
  def to_le(list_of_floats), do: to(list_of_floats, :le)

  defp from([], _), do: []

  defp from([w0, w1 | tail], endianness) do
    [from(w0, w1, endianness) | from(tail, endianness)]
  end

  defp from(w0, w1, :be) do
    <<value::float-32>> = <<w0::16, w1::16>>
    value
  end

  defp from(w0, w1, :le) do
    <<value::float-32>> = <<w1::16, w0::16>>
    value
  end

  defp to([], _), do: []

  defp to([f | tail], endianness) do
    [w0, w1] = to(f, endianness)
    [w0, w1 | to(tail, endianness)]
  end

  defp to(f, :be) do
    <<w0::16, w1::16>> = <<f::float-32>>
    [w0, w1]
  end

  defp to(f, :le) do
    <<w0::16, w1::16>> = <<f::float-32>>
    [w1, w0]
  end
end
