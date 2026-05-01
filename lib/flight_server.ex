defmodule FlightServer do
  @expiry_seconds 30

  def start(flight) do
    pid = spawn(fn -> loop(flight) end)
    Process.register(pid, :flight_server)
    pid
  end

  def loop(%Flight{} = flight) do
    receive do
      {:add_passenger, name, email, caller} ->
        new_flight = Flight.add_passenger(flight, name, email)
        passenger_id = map_size(new_flight.passengers)
        send(:audit_server, {:log, "Pasajero registrado: #{name} (id=#{passenger_id})"})
        send(caller, {:ok, passenger_id})
        loop(new_flight)

      {:reserve_seat, passenger_id, seat_id, caller} ->
        case Flight.reserve_seat(flight, passenger_id, seat_id) do
          {:ok, new_flight, reservation_id} ->
            send(:audit_server, {:log, "Asiento #{seat_id} reservado por pasajero #{passenger_id} (reserva=#{reservation_id})"})
            send(caller, {:ok, reservation_id})
            schedule_expiry(reservation_id)
            loop(new_flight)

          {:error, reason} ->
            send(:audit_server, {:log, "Intento de reserva fallido para asiento #{seat_id}: #{reason}"})
            send(caller, {:error, reason})
            loop(flight)
        end

      {:confirm_reservation, reservation_id, caller} ->
        case Flight.confirm_reservation(flight, reservation_id) do
          {:ok, new_flight} ->
            send(:audit_server, {:log, "Reserva #{reservation_id} confirmada"})
            send(caller, :ok)
            loop(new_flight)

          {:error, reason} ->
            send(caller, {:error, reason})
            loop(flight)
        end

      {:cancel_reservation, reservation_id, caller} ->
        case Flight.cancel_reservation(flight, reservation_id) do
          {:ok, new_flight} ->
            send(:audit_server, {:log, "Reserva #{reservation_id} cancelada"})
            send(caller, :ok)
            loop(new_flight)

          {:error, reason} ->
            send(caller, {:error, reason})
            loop(flight)
        end

      {:expire_reservation, reservation_id} ->
        case Flight.expire_reservation(flight, reservation_id) do
          {:ok, new_flight} ->
            send(:audit_server, {:log, "Reserva #{reservation_id} expirada automaticamente"})
            loop(new_flight)

          {:error, _reason} ->
            loop(flight)
        end

      {:available_seats, caller} ->
        send(caller, {:seats, Flight.available_seats(flight)})
        loop(flight)

      {:stats, caller} ->
        send(caller, {:stats, Flight.stats(flight)})
        loop(flight)
    end
  end

  defp schedule_expiry(reservation_id) do
    server = self()

    worker = spawn(fn ->
      Process.sleep(@expiry_seconds * 1000)
      send(server, {:expire_reservation, reservation_id})
    end)

    Process.monitor(worker)
  end
end
