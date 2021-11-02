defmodule Modbus.Tcp.Client do
  alias Modbus.Tcp.Client
  alias Modbus.Tcp
  use GenServer
  @timeout 2000
  @port 502
  @ip {0,0,0,0}
  @active false
  require Logger
  @to 2000

  @moduledoc """
  TCP Master Client.

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

  {:ok, pid} = Master.start_link([ip: {10,77,0,2}, port: 502])

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

  defstruct ip: nil,
            port: nil,
            socket: nil,
            timeout: @to,
            active: false,
            transid: 0,
            status: nil,
            d_pid: nil,
            msg_len: 0,
            pending_msg: %{},
            cmd: nil


  @type client_option ::
        {:ip, {byte(),byte(),byte(),byte()}}
      | {:active, boolean}
      | {:port, non_neg_integer}
      | {:timeout, non_neg_integer}
  ##########################################
  # Public API
  ##########################################

  @doc """
  Starts the Client.

  `state` is a keyword list where:
  `ip` is the internet address to connect to.
  `port` is the tcp port number to connect to.
  `socket` is the port of the Modbus Client.
  `timeout` is the connection timeout.
  `active` the way in which massages are received.
  'transid' the actual transaction id.
  'status' the Client status.


  Returns `{:ok, pid}`.

  ## Example

  ```elixir
  Modbus.Tcp.Master.start_link([ip: {10,77,0,2}, port: 502, timeout: 2000])
  ```
  """
  @spec start_link([client_option], [term]) :: {:ok, pid} | {:error, term}
  def start_link(params, opts \\ []) do
    GenServer.start_link(__MODULE__, params, opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end


  @doc """
  Stops the Client.
  """
  @spec stop(GenServer.server()) :: :ok | :error
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Gets the state of the Client.
  """
  #@spec state(GenServer.server()) :: {term() | :closed, [uart_option]}
  def state(pid) do
    GenServer.call(pid, :state)
  end

  @doc """
  Configure the Modbus client (`status` must be `:closed`).
  """
  @spec configure(GenServer.server(), [client_option]) :: :ok | {:error, term}
  def configure(pid, params) do
    GenServer.call(pid, {:configure, params})
  end

  @doc """
  Connect the Modbus client to a server.
  """
  def connect(pid) do
    GenServer.call(pid, :connect)
  end

  @doc """
  Close the tcp port of the Modbus client.
  """
  def close(pid) do
    GenServer.call(pid, :close)
  end

   @doc """
  send a request to Modbus TCP Server.

  `cmd` is one of:

  - `{:rc, slave, address, count}` read `count` coils.
  - `{:ri, slave, address, count}` read `count` inputs.
  - `{:rhr, slave, address, count}` read `count` holding registers.
  - `{:rir, slave, address, count}` read `count` input registers.
  - `{:fc, slave, address, value}` force single coil.
  - `{:phr, slave, address, value}` preset single holding register.
  - `{:fc, slave, address, values}` force multiple coils.
  - `{:phr, slave, address, values}` preset multiple holding registers.

  Returns `:ok`.
  """
  def request(pid, cmd) do
    GenServer.call(pid, {:request, cmd})
  end

  @doc """
  Reads the confirmation of the connected Modbus server.
  """
  def confirmation(pid) do
    GenServer.call(pid, :confirmation)
  end

  @doc """
  In active mode, flushed the pending messages.
  """
  def flush(pid) do
    GenServer.call(pid, :flush)
  end

  #callbacks
  def init(args) do
    port = args[:port] || @port
    ip = args[:ip] || @ip
    timeout = args[:timeout] || @timeout
    status = :closed
    active =
      if args[:active] == nil do
        @active
      else
        args[:active]
      end
    state = %Client{ip: ip, port: port, timeout: timeout, status: status, active: active}
    {:ok, state}
  end

  def handle_call(:state, from, state) do
    Logger.debug(inspect(from))
    {:reply, state, state}
  end

  def handle_call({:configure, args}, _from, state) do
    case state.status do
      :closed ->
        port = args[:port] || state.port
        ip = args[:ip] || state.ip
        timeout = args[:timeout] || state.timeout
        d_pid = args[:d_pid] || state.d_pid
        active =
          if args[:active] == nil do
            state.active
          else
            args[:active]
          end
        new_state = %Client{state | ip: ip, port: port, timeout: timeout, active: active, d_pid: d_pid}
        {:reply, :ok, new_state}
      _ ->
        {:reply, :error, state}
    end
  end

  def handle_call(:connect, {from,_ref}, state) do
    Logger.debug(inspect(state))
    Logger.debug(inspect(from))
    case :gen_tcp.connect(state.ip, state.port, [:binary, packet: :raw, active: state.active], state.timeout) do
      {:ok, socket} ->
        ctrl_pid =
          if state.d_pid == nil do
            from
          else
            state.d_pid
          end
        new_state = %Client{state | socket: socket, status: :connected, d_pid: ctrl_pid} #state
        {:reply, :ok, new_state}
      {:error, reason} ->
        Logger.debug(inspect(reason))
        {:reply, {:error,reason}, state} #state
    end
  end

  def handle_call(:close, _from, state) do
    Logger.debug(inspect(state))
    if state.socket != nil do
      new_state = close_socket(state)
      {:reply, :ok, new_state}
    else
      Logger.info("No port to close")
      {:reply, {:error, :closed}, state} #state
    end
  end

  def handle_call({:request, cmd}, _from, state) do
    Logger.debug(inspect(state))
    case state.status do
      :connected ->
        request = Tcp.pack_req(cmd, state.transid)
        length = Tcp.res_len(cmd)
        case :gen_tcp.send(state.socket, request) do
          :ok ->
            new_state =
            if state.active do
              new_msg = Map.put(state.pending_msg, state.transid, cmd)
              n_msg =
                if (state.transid + 1 > 0xffff) do
                  0
                else
                  state.transid+1
                end
              %Client{state | msg_len: length, cmd: cmd, pending_msg: new_msg, transid: n_msg}
            else
              %Client{state | msg_len: length, cmd: cmd}
            end
            {:reply, :ok, new_state}
          {:error, :closed} ->
            new_state = close_socket(state)
            {:reply, {:error, :closed}, new_state}
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      :closed ->
        {:reply, {:error, :closed}, state}
    end
  end
#only in passive mode
  def handle_call(:confirmation, _from, state) do
    Logger.debug(inspect(state))
    if state.active do
      {:reply, :error, state}
    else
      case state.status do
        :connected ->
          case :gen_tcp.recv(state.socket, state.msg_len, state.timeout) do
            {:ok, response} ->
              values = Tcp.parse_res(state.cmd, response, state.transid)
              Logger.info(inspect(values))

              n_msg =
                if (state.transid + 1 > 0xffff) do
                  0
                else
                  state.transid+1
                end
              new_state = %Client{state | transid: n_msg, cmd: nil, msg_len: 0}
              case values do
                nil -> # escribió algo
                  {:reply, :ok, new_state}
                _ -> # leemos algo
                  {:reply, {:ok, values}, new_state}
              end
            {:error, reason} ->
              Logger.debug("Error: #{reason}")
              #cerrar?
              new_state = close_socket(state)
              new_state = %Client{new_state | cmd: nil, msg_len: 0}
              {:reply, {:error, reason}, new_state}
          end
        :closed ->
          {:reply, {:error, :closed}, state}
      end
    end
  end

  def handle_call(:flush, _from, state) do
    new_state = %Client{state | pending_msg: %{}}
    {:reply, {:ok, state.pending_msg}, new_state}
  end

  #only for active mode
  def handle_info({:tcp,_port, response}, state) do
    Logger.debug("From tcp port: #{inspect(response)}")
    Logger.debug("State: #{inspect(state)}")

    h = :binary.at(response,0)
    l = :binary.at(response,1)
    transid= h*256+l

    Logger.debug("transid: #{transid}")

    case Map.fetch(state.pending_msg, transid) do
      :error ->
        Logger.debug("unknown transaction id")
        {:noreply, state}
      {:ok, cmd} ->
        values = Tcp.parse_res(cmd, response, transid)
        msg = {:modbus_tcp, cmd, values}
        send(state.d_pid, msg)
        new_pending_msg = Map.delete(state.pending_msg, transid)
        new_state = %Client{state | cmd: nil, msg_len: 0, pending_msg: new_pending_msg}
        {:noreply, new_state}
    end

  end

  def handle_info({:tcp_closed,_port}, state) do
    Logger.debug("Server close the port")
    new_state = close_socket(state)
    {:noreply, new_state}
  end

  def handle_info(msg, state) do
    Logger.debug("Can't parse: #{inspect(msg)}")
    {:noreply, state}
  end

  defp close_socket(state) do
    :ok = :gen_tcp.close(state.socket)
    new_state = %Client{state | socket: nil, status: :closed}
    new_state
  end

end
