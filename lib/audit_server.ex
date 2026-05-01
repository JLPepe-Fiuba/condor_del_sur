defmodule AuditServer do
  def start do
    pid = spawn(fn -> loop([]) end)
    Process.register(pid, :audit_server)
    pid
  end

  def loop(events) do
    receive do
      {:log, event} ->
        timestamp = DateTime.utc_now() |> DateTime.to_string()
        entry = "[#{timestamp}] #{event}"
        IO.puts("  [AUDITORIA] #{entry}")
        loop([entry | events])

      {:get_log, caller} ->
        send(caller, {:log, Enum.reverse(events)})
        loop(events)
    end
  end
end
