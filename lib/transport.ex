defmodule Modbus.Transport do
  @moduledoc false
  @callback open(opts :: keyword()) ::
              {:ok, id :: any()} | {:error, reason :: any()}
  @callback read(id :: any(), count :: integer(), timeout :: integer()) ::
              {:ok, packet :: binary()} | {:error, reason :: any()}
  @callback write(id :: any(), packet :: binary()) :: :ok | {:error, reason :: any()}
  @callback close(id :: any()) :: :ok | {:error, reason :: any()}

  def module(:tcp), do: Modbus.Tcp.Transport
  def module(trans), do: trans

  def open(mod, opts) do
    mod.open(opts)
  end

  def read({mod, id}, count, timeout) do
    mod.read(id, count, timeout)
  end

  def write({mod, id}, packet) do
    mod.write(id, packet)
  end

  def close({mod, id}) do
    mod.close(id)
  end
end
