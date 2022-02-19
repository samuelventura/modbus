defmodule Modbus.Tcp.Master do
  @moduledoc """
  TCP Master server.

  ## Example

  ```elixir
  # run with: mix opto22
  alias Modbus.Tcp.Master

  # opto22 learning center configured with script/opto22.otg
  # the otg is for an R2 but seems to work for R1, EB1, and EB2
  # digital points increment address by 4 per module and by 1 per point
  # analog points increment address by 8 per module and by 2 per point

  {:ok, pid} = Master.connect(ip: {10, 77, 0, 10}, port: 502)

  # turn on 'alarm'
  :ok = Master.exec(pid, {:fc, 1, 4, 1})
  # turn on 'outside light'
  :ok = Master.exec(pid, {:fc, 1, 5, 1})
  # turn on 'inside light'
  :ok = Master.exec(pid, {:fc, 1, 6, 1})
  # turn on 'freezer door status'
  :ok = Master.exec(pid, {:fc, 1, 7, 1})

  :timer.sleep(400)

  # turn off all digital outputs
  :ok = Master.exec(pid, {:fc, 1, 4, [0, 0, 0, 0]})

  # read the 'emergency' switch
  {:ok, [0]} = Master.exec(pid, {:rc, 1, 8, 1})

  # read the 'fuel level' knob (0 to 10,000)
  {:ok, data} = Master.exec(pid, {:rir, 1, 32, 2})
  [_] = Modbus.IEEE754.from_2n_regs(data, :be)

  # write to the 'fuel display' (0 to 10,000)
  data = Modbus.IEEE754.to_2_regs(+5000.0, :be)
  :ok = Master.exec(pid, {:phr, 1, 16, data})
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
  `ip` is the internet address to connect to.
  `port` is the tcp port number to connect to.
  `timeout` is the connection timeout.

  Returns `{:ok, ref}` | `{:error, reason}`.

  ## Example

  ```elixir
  Modbus.Tcp.Master.connect(ip: {10,77,0,10}, port: 502, timeout: 2000)
  ```
  """

  def connect(opts) do
    ip = Keyword.fetch!(opts, :ip)
    port = Keyword.fetch!(opts, :port)
    timeout = Keyword.get(opts, :timeout, @to)
    opts = [:binary, packet: :raw, active: false]

    case :gen_tcp.connect(ip, port, opts, timeout) do
      {:ok, sid} ->
        {:ok, aid} = Agent.start_link(fn -> 0 end)
        state = %{socket: sid, agent: aid}
        {:ok, state}

      error ->
        error
    end
  end

  @doc """
  Closes the connection.
  """
  def close(ref) do
    %{socket: sid, agent: aid} = ref
    :gen_tcp.close(sid)
    Agent.stop(aid)
  end

  @doc """
  Executes a Modbus TCP command.

  `cmd` is one of:

  - `{:rc, slave, address, count}` read `count` coils.
  - `{:ri, slave, address, count}` read `count` inputs.
  - `{:rhr, slave, address, count}` read `count` holding registers.
  - `{:rir, slave, address, count}` read `count` input registers.
  - `{:fc, slave, address, value}` force single coil.
  - `{:phr, slave, address, value}` preset single holding register.
  - `{:fc, slave, address, values}` force multiple coils.
  - `{:phr, slave, address, values}` preset multiple holding registers.

  Returns `:ok` | `{:ok, [values]}`.
  """
  def exec(ref, cmd, timeout \\ @to) do
    %{socket: sid, agent: aid} = ref
    transid = Agent.get_and_update(aid, fn tid -> {tid, tid + 1} end)

    case request(cmd, transid) do
      {:ok, request, length} ->
        # clear input buffer
        :gen_tcp.recv(sid, 0, 0)

        case :gen_tcp.send(sid, request) do
          :ok ->
            case :gen_tcp.recv(sid, length, timeout) do
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
