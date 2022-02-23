# modbus

Modbus library with TCP Master & Slave.

For Serial RTU see [baud](https://github.com/samuelventura/baud).

Based on:

- http://modbus.org/docs/PI_MBUS_300.pdf
- http://modbus.org/docs/Modbus_Messaging_Implementation_Guide_V1_0b.pdf
- http://modbus.org/docs/Modbus_over_serial_line_V1_02.pdf

## Installation and Usage

1. Add [`modbus`](https://hex.pm/packages/modbus) to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:modbus, "~> MAJOR.MINOR"}]
  end
  ```

2. Connect the TCP master to the testing TCP slave:

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
  ...
  ```

3. Connect the TCP master to a real industrial Opto22 device:

  ```elixir
  # run with: mix opto22
  alias Modbus.Master

  # opto22 learning center configured with script/opto22.otg
  # the otg is for an R2 but seems to work for R1, EB1, and EB2
  # digital points increment address by 4 per module and by 1 per point
  # analog points increment address by 8 per module and by 2 per point

  {:ok, master} = Master.open(ip: {10, 77, 0, 10}, port: 502)

  # turn on 'alarm'
  :ok = Master.exec(master, {:fc, 1, 4, 1})
  # turn on 'outside light'
  :ok = Master.exec(master, {:fc, 1, 5, 1})
  # turn on 'inside light'
  :ok = Master.exec(master, {:fc, 1, 6, 1})
  # turn on 'freezer door status'
  :ok = Master.exec(master, {:fc, 1, 7, 1})

  :timer.sleep(400)

  # turn off all digital outputs
  :ok = Master.exec(master, {:fc, 1, 4, [0, 0, 0, 0]})

  # read the 'emergency' switch
  {:ok, [0]} = Master.exec(master, {:rc, 1, 8, 1})

  # read the 'fuel level' knob (0 to 10,000)
  {:ok, data} = Master.exec(master, {:rir, 1, 32, 2})
  [_] = Modbus.Float.from_be(data)

  # write to the 'fuel display' (0 to 10,000)
  data = Modbus.Float.to_be([+5000.0])
  :ok = Master.exec(master, {:phr, 1, 16, data})

  :ok = Master.close(master)
  ```

## Endianess

- [Erlang default endianess is BIG](http://erlang.org/doc/programming_examples/bit_syntax.html#Defaults)
- [MODBUS default endianess is BIG (p.34)](http://modbus.org/docs/PI_MBUS_300.pdf)
- [MODBUS CRC endianess is LITTLE (p.16)](http://modbus.org/docs/PI_MBUS_300.pdf)
- [Opto22 FLOAT endianess is BIG (p.27)](http://www.opto22.com/documents/1678_Modbus_TCP_Protocol_Guide.pdf)

## Roadmap

Future

- [ ] Transport behaviour for serial and socket
- [ ] Protocol behaviour for TCP, RTU, and ASCII
- [ ] Improve documentation and samples
- [ ] Improve error handling
- [ ] TCP<->RTU translator

Version 0.4.0

- [x] Transport and protocol behaviours
- [x] API refactored (breaking changes)
- [x] Basic crash and socket testing
- [x] Added echo server as testing helper

Version 0.3.9

- [x] Basic crash testing
- [x] Resilient master, slave, and shared model

Version 0.3.8

- [x] Shared and slave for testing purposes only
- [x] Removed client (no clear api)

Version 0.3.7

- [x] Changed little endian flag from :se to :le

Version 0.3.6

- [x] Added endianness flag to float helpers

Version 0.3.5

- [x] Added float helper

Version 0.3.4

- [x] Fixed RTU CRC endianess

Version 0.3.3

- [x] Shared model slave implementation

Version 0.3.2

- [x] Added request length prediction
- [x] Refactored namespaces to avoid baud clash
- [x] Tcp master api updated to match baud rtu master api

Version 0.3.1

- [x] Added master/slave test for each code
- [x] Added response length prediction
- [x] Added a couple of helpers to tcp and rtu api
- [x] A reference-only tcp slave added in test helper

Version 0.3.0

- [x] Modbus TCP slave: wont fix, to be implemented as forward plugin
- [x] API breaking changes

Version 0.2.0

- [x] Updated documentation
- [x] Renamed commands to match spec wording

Version 0.1.0

- [x] Modbus TCP master
- [x] Request/response packet builder and parser
- [x] Device model to emulate slave interaction
