import Config

config :modbus,
  protocols: [tcp: Modbus.Tcp.Protocol, rtu: Modbus.Rtu.Protocol],
  transports: [tcp: Modbus.Tcp.Transport]
