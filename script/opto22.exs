# run with: mix opto22
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

{:ok, pid} = Master.start_link(ip: {10, 77, 0, 10}, port: 502)

# turn off m1.p0
:ok = Master.exec(pid, {:fc, 1, 4, 0})
# turn on m1.p1
:ok = Master.exec(pid, {:fc, 1, 5, 1})
# alternate m1.p2 and m1.p3
:ok = Master.exec(pid, {:fc, 1, 6, [1, 0]})

# https://www.h-schmidt.net/FloatConverter/IEEE754.html
# write -5V (IEEE 754 float) to m3.p0
# <<-5::float-32>> -> <<192, 160, 0, 0>>
:ok = Master.exec(pid, {:phr, 1, 24, [0xC0A0, 0x0000]})
:ok = Master.exec(pid, {:phr, 1, 24, Modbus.IEEE754.to_2_regs(-5.0, :be)})
# write +5V (IEEE 754 float) to m3.p1
# <<+5::float-32>> -> <<64, 160, 0, 0>>
:ok = Master.exec(pid, {:phr, 1, 26, [0x40A0, 0x0000]})
:ok = Master.exec(pid, {:phr, 1, 26, Modbus.IEEE754.to_2_regs(+5.0, :be)})

# outputs settle delay
:timer.sleep(20)

# read previous coils as inputs
{:ok, [0, 1, 1, 0]} = Master.exec(pid, {:ri, 1, 4, 4})

# read previous analog channels as input registers
{:ok, [0xC0A0, 0x0000, 0x40A0, 0x0000]} = Master.exec(pid, {:rir, 1, 24, 4})
{:ok, data} = Master.exec(pid, {:rir, 1, 24, 4})
[-5.0, +5.0] = Modbus.IEEE754.from_2n_regs(data, :be)
