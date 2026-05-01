defmodule Flight do
  defstruct [
    :flight_number,
    next_reservation_id: 1,
    seats: %{},
    passengers: %{},
    reservations: %{}
  ]

  @spec new(any(), integer(), any()) :: %Flight{
          flight_number: any(),
          next_reservation_id: 1,
          passengers: %{},
          reservations: %{},
          seats: map()
        }
  def new(flight_number, rows, cols) do
    seats =
      for row <- 1..rows, col <- 1..cols, into: %{} do
        id = "#{row}#{<<col + 64>>}"
        {id, %Seat{id: id, row: row, column: col, status: :available}}
      end

    %Flight{flight_number: flight_number, seats: seats}
  end

  def add_passenger(%Flight{} = flight, name, email) do
    id = map_size(flight.passengers) + 1
    passenger = %Passenger{id: id, name: name, email: email}

    %Flight{flight | passengers: Map.put(flight.passengers, id, passenger)}
  end

  def reserve_seat(%Flight{} = flight, passenger_id, seat_id) do
    cond do
      not Map.has_key?(flight.passengers, passenger_id) ->
        {:error, :passenger_not_found}

      not Map.has_key?(flight.seats, seat_id) ->
        {:error, :seat_not_found}

      flight.seats[seat_id].status != :available ->
        {:error, :seat_not_available}

      true ->
        reservation = %Reservation{
          id: flight.next_reservation_id,
          passenger_id: passenger_id,
          seat_id: seat_id,
          created_at: System.monotonic_time(:second),
          status: :pending
        }

        %Seat{} = seat = flight.seats[seat_id]
        updated_seat = %{seat | status: :reserved}

        new_flight = %Flight{
          flight
          | next_reservation_id: flight.next_reservation_id + 1,
            seats: Map.put(flight.seats, seat_id, updated_seat),
            reservations: Map.put(flight.reservations, reservation.id, reservation)
        }

        {:ok, new_flight, reservation.id}
    end
  end

  def confirm_reservation(%Flight{} = flight, reservation_id) do
    case Map.get(flight.reservations, reservation_id) do
      nil ->
        {:error, :reservation_not_found}

      %Reservation{status: :confirmed} ->
        {:error, :already_confirmed}

      %Reservation{status: status} when status in [:cancelled, :expired] ->
        {:error, :reservation_not_pending}

      %Reservation{} = reservation ->
        updated_reservation = %Reservation{reservation | status: :confirmed}
        %Seat{} = seat = flight.seats[reservation.seat_id]
        updated_seat = %{seat | status: :confirmed}

        new_flight = %Flight{
          flight
          | reservations: Map.put(flight.reservations, reservation_id, updated_reservation),
            seats: Map.put(flight.seats, reservation.seat_id, updated_seat)
        }

        {:ok, new_flight}
    end
  end

  def cancel_reservation(%Flight{} = flight, reservation_id) do
    case Map.get(flight.reservations, reservation_id) do
      nil ->
        {:error, :reservation_not_found}

      %Reservation{status: :confirmed} ->
        {:error, :already_confirmed}

      %Reservation{status: status} when status in [:cancelled, :expired] ->
        {:error, :reservation_not_pending}

      %Reservation{} = reservation ->
        updated_reservation = %Reservation{reservation | status: :cancelled}
        %Seat{} = seat = flight.seats[reservation.seat_id]
        updated_seat = %{seat | status: :available}

        new_flight = %Flight{
          flight
          | reservations: Map.put(flight.reservations, reservation_id, updated_reservation),
            seats: Map.put(flight.seats, reservation.seat_id, updated_seat)
        }

        {:ok, new_flight}
    end
  end

  def expire_reservation(%Flight{} = flight, reservation_id) do
    case Map.get(flight.reservations, reservation_id) do
      nil ->
        {:error, :reservation_not_found}

      %Reservation{status: status} when status != :pending ->
        {:error, :reservation_not_pending}

      %Reservation{} = reservation ->
        updated_reservation = %Reservation{reservation | status: :expired}
        %Seat{} = seat = flight.seats[reservation.seat_id]
        updated_seat = %{seat | status: :available}

        new_flight = %Flight{
          flight
          | reservations: Map.put(flight.reservations, reservation_id, updated_reservation),
            seats: Map.put(flight.seats, reservation.seat_id, updated_seat)
        }

        {:ok, new_flight}
    end
  end

  def available_seats(%Flight{} = flight) do
    flight.seats
    |> Map.values()
    |> Enum.filter(fn seat -> seat.status == :available end)
  end

  def stats(%Flight{} = flight) do
    reservations = Map.values(flight.reservations)

    %{
      flight_number: flight.flight_number,
      total_seats: map_size(flight.seats),
      available: length(available_seats(flight)),
      reserved: Enum.count(reservations, &(&1.status == :pending)),
      confirmed: Enum.count(reservations, &(&1.status == :confirmed)),
      cancelled: Enum.count(reservations, &(&1.status == :cancelled)),
      expired: Enum.count(reservations, &(&1.status == :expired))
    }
  end
end
