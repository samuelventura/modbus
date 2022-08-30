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
  {:ok, master} = Master.start_link(ip: {127, 0, 0, 1}, port: port)

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

  :ok = Master.stop(master)
  :ok = Slave.stop(slave)
  ```
  """
  alias Modbus.Transport
  alias Modbus.Protocol
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
  Modbus.Master.start_link(ip: {10,77,0,10}, port: 502, timeout: 2000)
  ```
  """

  def start_link(opts) do
    GenServer.start_link(__MODULE__.Server, opts)
  end

  @doc """
  Closes the connection.

  Returns `:ok` | `{:error, reason}`.
  """
  def stop(master) do
    GenServer.stop(master)
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
  def exec(master, cmd, timeout \\ @to)
      when is_tuple(cmd) and is_integer(timeout) do
    GenServer.call(master, {:exec, cmd, timeout})
  end

  defmodule Connection do
    @to 2000

    def open(opts) do
      transm = Keyword.get(opts, :trans, Modbus.Tcp.Transport)
      protom = Keyword.get(opts, :proto, Modbus.Tcp.Protocol)
      tid = Protocol.next(protom, nil)

      case Transport.open(transm, opts) do
        {:ok, transi} ->
          transp = {transm, transi}
          {:ok, %{trans: transp, proto: protom, tid: tid}}

        {:error, reason} ->
          {:error, reason}
      end
    end

    def close(%{trans: trans}) do
      Transport.close(trans)
    end

    def exec(state, cmd, timeout \\ @to) do
      %{trans: trans, proto: proto, tid: tid} = state
      state = Map.put(state, :tid, Protocol.next(state.proto, tid))

      result =
        case request(proto, cmd, tid) do
          {:ok, request, length} ->
            case Transport.write(trans, request) do
              :ok ->
                case Transport.readn(trans, length, timeout) do
                  {:ok, response} ->
                    values = Protocol.parse_res(proto, cmd, response, tid)

                    case values do
                      nil -> :ok
                      _ -> {:ok, values}
                    end

                  {:error, reason} ->
                    {:error, reason}
                end

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {state, result}
    end

    def get_tid(state), do: Map.get(state, :tid)
    def put_tid(state, tid), do: Map.put(state, :tid, tid)

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

  defmodule Server do
    @moduledoc false
    use GenServer

    def init(opts) do
      case Connection.open(opts) do
        {:ok, state} -> {:ok, state}
        {:error, reason} -> {:stop, reason}
      end
    end

    def terminate(_reason, state) do
      Connection.close(state)
    end

    def handle_call({:get, :tid}, _from, state) do
      {:reply, Connection.get_tid(state), state}
    end

    def handle_call({:update, :tid, tid}, _from, state) do
      {:reply, :ok, Connection.put_tid(state, tid)}
    end

    def handle_call({:exec, cmd, timeout}, _from, state) do
      {state, result} = Connection.exec(state, cmd, timeout)
      {:reply, result, state}
    end
  end
end
