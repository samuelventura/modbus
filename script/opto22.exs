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
