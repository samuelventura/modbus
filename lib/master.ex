defmodule Modbus.Tcp.Master do
  @moduledoc """
  TCP Master server.

  ## Example

  ```elixir
  # run with: mix slave
  alias Modbus.Tcp.Slave
  alias Modbus.Tcp.Master

  # start your slave with a shared model
  model = %{0x50 => %{{:c, 0x5152} => 0}}
  {:ok, spid} = Slave.start_link(model: model)
  # get the assigned tcp port
  port = Slave.port(spid)

  # interact with it through the master
  {:ok, mpid} = Master.start_link(ip: {127, 0, 0, 1}, port: port)
  :ok = Master.exec(mpid, {:fc, 0x50, 0x5152, 0})
  {:ok, [0]} = Master.exec(mpid, {:rc, 0x50, 0x5152, 1})
  :ok = Master.exec(mpid, {:fc, 0x50, 0x5152, 1})
  {:ok, [1]} = Master.exec(mpid, {:rc, 0x50, 0x5152, 1})
  ```
  """
  alias Modbus.Tcp
  @to 2000

  ##########################################
  # Public API
  ##########################################

  @doc """
  Opens the connection.

  `opts` is a keyword list where:
  - `ip` is the internet address to connect to.
  - `port` is the tcp port number to connect to.
  - `timeout` is the optional connection timeout.

  Returns `{:ok, pid}` | `{:error, reason}`.

  ## Example

  ```elixir
  Modbus.Tcp.Master.start_link(ip: {10,77,0,10}, port: 502, timeout: 2000)
  ```
  """

  def start_link(opts) do
    ip = Keyword.fetch!(opts, :ip)
    port = Keyword.fetch!(opts, :port)
    timeout = Keyword.get(opts, :timeout, @to)
    init = %{ip: ip, port: port, timeout: timeout}
    GenServer.start_link(__MODULE__.Server, init)
  end

  @doc """
  Closes the connection.
  """
  def stop(pid) do
    GenServer.stop(pid)
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
  def exec(pid, cmd, timeout \\ @to) when is_tuple(cmd) and is_integer(timeout) do
    GenServer.call(pid, {:exec, cmd, timeout})
  end

  defmodule Server do
    @moduledoc false
    use GenServer

    def init(init) do
      %{ip: ip, port: port, timeout: timeout} = init
      opts = [:binary, packet: :raw, active: false]

      case :gen_tcp.connect(ip, port, opts, timeout) do
        {:ok, sid} ->
          state = %{socket: sid, transid: 0}
          {:ok, state}

        {:error, reason} ->
          {:stop, reason}
      end
    end

    def handle_call({:exec, cmd, timeout}, _from, state) do
      %{socket: socket, transid: transid} = state
      resp = exec(socket, cmd, transid, timeout)
      {:reply, resp, Map.put(state, :transid, transid + 1)}
    end

    defp exec(socket, cmd, transid, timeout) do
      case request(cmd, transid) do
        {:ok, request, length} ->
          # clear input buffer
          :gen_tcp.recv(socket, 0, 0)

          case :gen_tcp.send(socket, request) do
            :ok ->
              case :gen_tcp.recv(socket, length, timeout) do
                {:ok, response} ->
                  values = Tcp.parse_res(cmd, response, transid)

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

    defp request(cmd, transid) do
      try do
        request = Tcp.pack_req(cmd, transid)
        length = Tcp.res_len(cmd)
        {:ok, request, length}
      rescue
        _ ->
          {:error, {:invalid, cmd}}
      end
    end
  end
end
