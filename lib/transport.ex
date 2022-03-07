defmodule Modbus.Transport do
  @moduledoc false
  @callback open(opts :: keyword()) ::
              {:ok, id :: any()} | {:error, reason :: any()}
  @callback readp(id :: any()) :: {:ok, packet :: binary()} | {:error, reason :: any()}
  @callback readn(id :: any(), count :: integer(), timeout :: integer()) ::
              {:ok, packet :: binary()} | {:error, reason :: any()}
  @callback write(id :: any(), packet :: binary()) :: :ok | {:error, reason :: any()}
  @callback close(id :: any()) :: :ok | {:error, reason :: any()}

  def open(mod, opts) do
    mod.open(opts)
  end

  def readn({mod, id}, count, timeout) do
    mod.readn(id, count, timeout)
  end

  def readp({mod, id}) do
    mod.readp(id)
  end

  def write({mod, id}, packet) do
    mod.write(id, packet)
  end

  def close({mod, id}) do
    mod.close(id)
  end
end
