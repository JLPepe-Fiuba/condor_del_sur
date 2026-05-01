defmodule Demo do
  def run do
    IO.puts("\n* * * Sistema de reservas - Cóndor del Sur  * * *\n")

    AuditServer.start()
    flight = Flight.new("TP001", 6, 6)
    FlightServer.start(flight)

    IO.puts("Vuelo TP001 creado con #{6 * 6} asientos")
    IO.puts("Registrando pasajeros...")
    passengers = register_passengers(10)
    IO.puts("10 pasajeros registrados\n")

    IO.puts("||Caso 1: reserva y confirmacion||")
    send(:flight_server, {:reserve_seat, Enum.at(passengers, 0), "1A", self()})
    reservation_1 =
      receive do
        {:ok, id} ->
          IO.puts("Pasajero 1 reservo el asiento 1A (reserva ##{id})")
          id
        {:error, reason} ->
          IO.puts("Error: #{reason}")
          nil
      end

    if reservation_1 do
      IO.puts("Procesando pago para reserva ##{reservation_1}...")
      Process.sleep(1_000)
      IO.puts("Pago aprobado")
      send(:flight_server, {:confirm_reservation, reservation_1, self()})
      receive do
        :ok -> IO.puts("Reserva ##{reservation_1} confirmada")
        {:error, reason} -> IO.puts("Error al confirmar: #{reason}")
      end
    end

    IO.puts("\n||Caso 2: reserva y cancelacion||")
    send(:flight_server, {:reserve_seat, Enum.at(passengers, 1), "2B", self()})
    reservation_2 =
      receive do
        {:ok, id} ->
          IO.puts("Pasajero 2 reservo asiento 2B (reserva ##{id})")
          id
        {:error, reason} ->
          IO.puts("Error: #{reason}")
          nil
      end

    if reservation_2 do
      send(:flight_server, {:cancel_reservation, reservation_2, self()})
      receive do
        :ok -> IO.puts("Reserva ##{reservation_2} cancelada, asiento 2B disponible de nuevo")
        {:error, reason} -> IO.puts("Error al cancelar: #{reason}")
      end
    end

    IO.puts("\n||Caso 3: expiracion automatica||")
    send(:flight_server, {:reserve_seat, Enum.at(passengers, 2), "3C", self()})
    reservation_3 =
      receive do
        {:ok, id} ->
          IO.puts("Pasajero 3 reservo asiento 3C (reserva ##{id})")
          IO.puts("Esperando 32 segundos para que expire...")
          id
        {:error, reason} ->
          IO.puts("Error: #{reason}")
          nil
      end

    if reservation_3 do
      Process.sleep(32_000)
      IO.puts("Tiempo cumplido")

      send(:flight_server, {:stats, self()})
      receive do
        {:stats, stats} ->
          IO.puts("Reservas expiradas: #{stats.expired}")
      end
    end

    IO.puts("\n||Caso 4: concurrencia||")
    parent = self()

    for i <- 3..9 do #7 pasajeros compitiendo por el mismo asiento
      passenger_id = Enum.at(passengers, i)
      spawn(fn ->
        send(:flight_server, {:reserve_seat, passenger_id, "4D", parent})
      end)
    end

    results =
      Enum.map(1..7, fn _ ->
        receive do
          {:ok, id} -> {:ok, id}
          {:error, reason} -> {:error, reason}
        after
          5_000 -> {:error, :timeout}
        end
      end)

    successes = Enum.filter(results, fn {status, _} -> status == :ok end)
    failures = Enum.filter(results, fn {status, _} -> status == :error end)

    IO.puts("Resultados:")
    Enum.each(results, fn
      {:ok, id} -> IO.puts("  reserva exitosa (id=#{id})")
      {:error, reason} -> IO.puts("  fallo: #{reason}")
    end)

    IO.puts("Solo #{length(successes)} pasajero gano el asiento 4D")
    IO.puts("#{length(failures)} pasajeros no pudieron reservarlo")

    IO.puts("\n||Guardando log||")
    spawn(fn ->
      send(:audit_server, {:get_log, self()})
      receive do
        {:log, events} ->
          content = Enum.join(events, "\n")
          File.write!("audit_log.txt", content)
          IO.puts("Log guardado en audit_log.txt (#{length(events)} eventos)")
      after
        3_000 -> IO.puts("Timeout al obtener log")
      end
    end)

    Process.sleep(500)

    IO.puts("\n|||-Estado final del vuelo-|||")
    send(:flight_server, {:stats, self()})
    receive do
      {:stats, stats} ->
        IO.puts("Vuelo:       #{stats.flight_number}")
        IO.puts("Total:       #{stats.total_seats} asientos")
        IO.puts("Disponibles: #{stats.available}")
        IO.puts("Reservados:  #{stats.reserved} (pendientes)")
        IO.puts("Confirmados: #{stats.confirmed}")
        IO.puts("Cancelados:  #{stats.cancelled}")
        IO.puts("Expirados:   #{stats.expired}")
    end
  end

  defp register_passengers(count) do
    Enum.map(1..count, fn i ->
      send(:flight_server, {:add_passenger, "Pasajero #{i}", "p#{i}@fi.uba.ar", self()})
      receive do
        {:ok, id} -> id
      after
        2_000 -> nil
      end
    end)
  end
end
