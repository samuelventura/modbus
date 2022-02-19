defmodule Modbus.SocketTest do
  use ExUnit.Case

  # these tests and the echo server is mostly to
  # grasp socket behaviour on normal process exit
  test "Listener is auto closed on normal process exit" do
    self = self()

    pid =
      spawn(fn ->
        ip = {127, 0, 0, 1}
        opts = [:binary, ip: ip, packet: :raw, active: false]
        {:ok, listener} = :gen_tcp.listen(0, opts)
        {:ok, {^ip, port}} = :inet.sockname(listener)
        send(self, {listener, ip, port})

        receive do
          reason -> Process.exit(self(), reason)
        end
      end)

    ref = :erlang.monitor(:process, pid)
    assert_receive {listener, ip, port}, 400
    {:ok, {^ip, ^port}} = :inet.sockname(listener)
    send(pid, :normal)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 400
    assert {:error, :einval} == :inet.sockname(listener)
  end

  test "Remote client is auto closed on normal process exit" do
    self = self()
    ip = {127, 0, 0, 1}
    opts = [:binary, ip: ip, packet: :raw, active: false]
    {:ok, listener} = :gen_tcp.listen(0, opts)
    {:ok, {^ip, port}} = :inet.sockname(listener)

    pid2 =
      spawn(fn ->
        {:ok, client2} = :gen_tcp.accept(listener)
        send(self, client2)

        receive do
          reason -> Process.exit(self(), reason)
        end
      end)

    pid =
      spawn(fn ->
        opts = [:binary, packet: :raw, active: false]
        {:ok, client} = :gen_tcp.connect(ip, port, opts)
        {:ok, {^ip, port}} = :inet.sockname(client)
        send(self, {client, ip, port})

        receive do
          reason -> Process.exit(self(), reason)
        end
      end)

    ref = :erlang.monitor(:process, pid)
    ref2 = :erlang.monitor(:process, pid2)
    assert_receive {client, ip, port}, 400
    assert_receive client2, 400
    {:ok, {^ip, ^port}} = :inet.sockname(client)
    {:ok, {_, _}} = :inet.sockname(client2)
    # the DOWN message seems to ensure client2 already closed
    send(pid2, :normal)
    assert_receive {:DOWN, ^ref2, :process, ^pid2, :normal}, 400
    assert {:error, :einval} == :inet.sockname(client2)
    send(pid, :normal)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 400
    assert {:error, :einval} == :inet.sockname(client)
  end

  test "Local client is auto closed on normal process exit" do
    self = self()
    ip = {127, 0, 0, 1}
    opts = [:binary, ip: ip, packet: :raw, active: false]
    {:ok, listener} = :gen_tcp.listen(0, opts)
    {:ok, {^ip, port}} = :inet.sockname(listener)

    pid2 =
      spawn(fn ->
        {:ok, client2} = :gen_tcp.accept(listener)
        send(self, client2)

        receive do
          reason -> Process.exit(self(), reason)
        end
      end)

    pid =
      spawn(fn ->
        opts = [:binary, packet: :raw, active: false]
        {:ok, client} = :gen_tcp.connect(ip, port, opts)
        {:ok, {^ip, port}} = :inet.sockname(client)
        send(self, {client, ip, port})

        receive do
          reason -> Process.exit(self(), reason)
        end
      end)

    ref = :erlang.monitor(:process, pid)
    ref2 = :erlang.monitor(:process, pid2)
    assert_receive {client, ip, port}, 400
    assert_receive client2, 400
    {:ok, {^ip, ^port}} = :inet.sockname(client)
    {:ok, {_, _}} = :inet.sockname(client2)
    send(pid, :normal)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 400
    assert {:error, :einval} == :inet.sockname(client)
    # the DOWN message seems to ensure client2 already closed
    send(pid2, :normal)
    assert_receive {:DOWN, ^ref2, :process, ^pid2, :normal}, 400
    assert {:error, :einval} == :inet.sockname(client2)
  end
end
