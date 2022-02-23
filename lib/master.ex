defmodule Modbus.Master do
  @moduledoc """
  Modbus Master.

  ## Example

  ```elixir
  # run with: mix slave
  alias Modbus.Slave
  alias Modbus.Master

  # start your slave with a shared model
  model = %{
  0x50 => %{
    {:c, 0x5152} => 0,
    {:i, 0x5354} => 0,
    {:i, 0x5355} => 1,
    {:hr, 0x5657} => 0x6162,
    {:ir, 0x5859} => 0x6364,
    {:ir, 0x585A} => 0x6566
  }
  }

  {:ok, slave} = Slave.start_link(model: model)
  # get the assigned tcp port
  port = Slave.port(slave)

  # interact with it
  {:ok, master} = Master.open(ip: {127, 0, 0, 1}, port: port)

  # read input
  {:ok, [0, 1]} = Master.exec(master, {:ri, 0x50, 0x5354, 2})
  # read input registers
  {:ok, [0x6364, 0x6566]} = Master.exec(master, {:rir, 0x50, 0x5859, 2})

  # toggle coil and read it back
  :ok = Master.exec(master, {:fc, 0x50, 0x5152, 0})
  {:ok, [0]} = Master.exec(master, {:rc, 0x50, 0x5152, 1})
  :ok = Master.exec(master, {:fc, 0x50, 0x5152, 1})
  {:ok, [1]} = Master.exec(master, {:rc, 0x50, 0x5152, 1})

  # increment holding register and read it back
  {:ok, [0x6162]} = Master.exec(master, {:rhr, 0x50, 0x5657, 1})
  :ok = Master.exec(master, {:phr, 0x50, 0x5657, 0x6163})
  {:ok, [0x6163]} = Master.exec(master, {:rhr, 0x50, 0x5657, 1})

  :ok = Master.close(master)
  :ok = Slave.stop(slave)
  ```
  """
  alias Modbus.Transport
  alias Modbus.Protocol
  alias Modbus.Registry
  @to 2000

  ##########################################
  # Public API
  ##########################################

  @doc """
  Opens the connection.

  `opts` is a keyword list where:
  - `trans` is the transport to use. Only the `:tcp` transport is available but other transports can be registered.
  - `proto` is the protocol to use. Available protocols are `:tcp` and `:rtu`. Defaults to `:tcp`.

  The rest of options are passed verbatim to the transport constructor.

  The following are the options needed by the default TCP transport.
  - `ip` is the internet address to connect to.
  - `port` is the tcp port number to connect to.
  - `timeout` is the optional connection timeout.

  Returns `{:ok, master}` | `{:error, reason}`.

  ## Example

  ```elixir
  Modbus.Master.open(ip: {10,77,0,10}, port: 502, timeout: 2000)
  ```
  """

  def open(opts) do
    transports = Application.fetch_env!(:modbus, :transports)
    protocols = Application.fetch_env!(:modbus, :protocols)
    trans = Keyword.get(opts, :trans, :tcp)
    proto = Keyword.get(opts, :proto, :tcp)
    transm = Keyword.fetch!(transports, trans)
    protom = Keyword.fetch!(protocols, proto)
    next = Protocol.next(protom, nil)
    {:ok, transi} = Transport.open(transm, opts)
    transp = {transm, transi}
    {:ok, _} = Registry.register({:tid, transp}, next)
    {:ok, {__MODULE__, transp, protom}}
  end

  @doc """
  Closes the connection.

  Returns `:ok` | `{:error, reason}`.
  """
  def close({__MODULE__, trans, _proto} = _master) do
    Transport.close(trans)
  end

  @doc """
  Executes a Modbus command.

  `cmd` is one of:

  - `{:rc, slave, address, count}` read `count` coils.
  - `{:ri, slave, address, count}` read `count` inputs.
  - `{:rhr, slave, address, count}` read `count` holding registers.
  - `{:rir, slave, address, count}` read `count` input registers.
  - `{:fc, slave, address, value}` force single coil.
  - `{:phr, slave, address, value}` preset single holding register.
  - `{:fc, slave, address, values}` force multiple coils.
  - `{:phr, slave, address, values}` preset multiple holding registers.

  Returns `:ok` | `{:ok, [values]}` | `{:error, reason}`.
  """
  def exec({__MODULE__, trans, proto} = _master, cmd, timeout \\ @to)
      when is_tuple(cmd) and is_integer(timeout) do
    {tid, _} = Registry.update({:tid, trans}, &Protocol.next(proto, &1))

    case request(proto, cmd, tid) do
      {:ok, request, length} ->
        case Transport.write(trans, request) do
          :ok ->
            case Transport.read(trans, length, timeout) do
              {:ok, response} ->
                values = Protocol.parse_res(proto, cmd, response, tid)

                case values do
                  nil -> :ok
                  _ -> {:ok, values}
                end

              error ->
                error
            end

          error ->
            error
        end

      error ->
        error
    end
  end

  defp request(proto, cmd, tid) do
    try do
      request = Protocol.pack_req(proto, cmd, tid)
      length = Protocol.res_len(proto, cmd)
      {:ok, request, length}
    rescue
      _ ->
        {:error, {:invalid, cmd}}
    end
  end
end
