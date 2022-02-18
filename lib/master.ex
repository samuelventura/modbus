defmodule Modbus.Tcp.Master do
  @moduledoc """
  TCP Master server.

  ## Example

  ```elixir
  #run with: mix opto22
  alias Modbus.Tcp.Master

  # opto22 rack configured as follows
  # m0 - 4p digital input
  #  p0 - 24V
  #  p1 - 0V
  #  p2 - m1.p2
  #  p3 - m1.p3
  # m1 - 4p digital output
  #  p0 - NC
  #  p1 - NC
  #  p2 - m0.p2
  #  p3 - m0.p3
  # m2 - 2p analog input (-10V to +10V)
  #  p0 - m3.p0
  #  p1 - m3.p1
  # m3 - 2p analog output (-10V to +10V)
  #  p0 - m2.p0
  #  p1 - m2.p1

  {:ok, pid} = Master.start_link(ip: {10,77,0,10}, port: 502)

  #turn off m1.p0
  :ok = Master.exec(pid, {:fc, 1, 4, 0})
  #turn on m1.p1
  :ok = Master.exec(pid, {:fc, 1, 5, 1})
  #alternate m1.p2 and m1.p3
  :ok = Master.exec(pid, {:fc, 1, 6, [1, 0]})

  #https://www.h-schmidt.net/FloatConverter/IEEE754.html
  #write -5V (IEEE 754 float) to m3.p0
  #<<-5::float-32>> -> <<192, 160, 0, 0>>
  :ok = Master.exec(pid, {:phr, 1, 24, [0xc0a0, 0x0000]})
  :ok = Master.exec(pid, {:phr, 1, 24, Modbus.IEEE754.to_2_regs(-5.0, :be)})
  #write +5V (IEEE 754 float) to m3.p1
  #<<+5::float-32>> -> <<64, 160, 0, 0>>
  :ok = Master.exec(pid, {:phr, 1, 26, [0x40a0, 0x0000]})
  :ok = Master.exec(pid, {:phr, 1, 26, Modbus.IEEE754.to_2_regs(+5.0, :be)})

  :timer.sleep(20) #outputs settle delay

  #read previous coils as inputs
  {:ok, [0, 1, 1, 0]} = Master.exec(pid, {:ri, 1, 4, 4})

  #read previous analog channels as input registers
  {:ok, [0xc0a0, 0x0000, 0x40a0, 0x0000]} = Master.exec(pid, {:rir, 1, 24, 4})
  {:ok, data} = Master.exec(pid, {:rir, 1, 24, 4})
  [-5.0, +5.0] = Modbus.IEEE754.from_2n_regs(data, :be)
  ```
  """
  use GenServer
  alias Modbus.Tcp
  @to 2000

  ##########################################
  # Public API
  ##########################################

  @doc """
  Starts the Server.

  `state` is a keyword list where:
  `ip` is the internet address to connect to.
  `port` is the tcp port number to connect to.
  `timeout` is the connection timeout.

  Returns `{:ok, pid}`.

  ## Example

  ```elixir
  Modbus.Tcp.Master.new(ip: {10,77,0,10}, port: 502, timeout: 2000)
  ```
  """

  def start_link(opts) do
    ip = Keyword.fetch!(opts, :ip)
    port = Keyword.fetch!(opts, :port)
    timeout = Keyword.get(opts, :timeout, @to)
    GenServer.start_link(__MODULE__, {ip, port, timeout})
  end

  def init({ip, port, timeout}) do
    opts = [:binary, packet: :raw, active: false]
    result = :gen_tcp.connect(ip, port, opts, timeout)

    case result do
      {:ok, socket} ->
        {:ok, {socket, 0}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @doc """
  Stops the Server.
  """
  def stop(pid) do
    GenServer.stop(pid)
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
  def exec(pid, cmd, timeout \\ @to) do
    GenServer.call(pid, {:exec, cmd, timeout})
  end

  def handle_call({:exec, cmd, timeout}, _from, {socket, transid}) do
    request = Tcp.pack_req(cmd, transid)
    length = Tcp.res_len(cmd)

    case :gen_tcp.send(socket, request) do
      {:error, reason} ->
        {:stop, reason}

      :ok ->
        case :gen_tcp.recv(socket, length, timeout) do
          {:ok, response} ->
            values = Tcp.parse_res(cmd, response, transid)

            case values do
              nil -> {:reply, :ok, {socket, transid + 1}}
              _ -> {:reply, {:ok, values}, {socket, transid + 1}}
            end

          {:error, reason} ->
            {:stop, reason}
        end
    end
  end
end
