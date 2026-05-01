defmodule FlightTest do
  use ExUnit.Case

  setup do
    flight =
      Flight.new("AR1234", 3, 3)
      |> Flight.add_passenger("Matias", "mati@fi.uba.ar")
      |> Flight.add_passenger("Manuel", "manu@fi.uba.ar")

    {:ok, flight: flight}
  end

  test "|Reservar un asiento disponible cambia su estado a :reserved|", %{flight: flight} do
    {:ok, new_flight, reservation_id} = Flight.reserve_seat(flight, 1, "1A")

    assert new_flight.seats["1A"].status == :reserved
    assert new_flight.reservations[reservation_id].status == :pending
  end

  test "|Reservar un asiento ya ocupado devuelve error|", %{flight: flight} do
    {:ok, flight2, _} = Flight.reserve_seat(flight, 1, "1A")
    result = Flight.reserve_seat(flight2, 2, "1A")

    assert result == {:error, :seat_not_available}
  end

  test "|Confirmar una reserva pendiente la pasa a :confirmed|", %{flight: flight} do
    {:ok, flight2, reservation_id} = Flight.reserve_seat(flight, 1, "1A")
    {:ok, flight3} = Flight.confirm_reservation(flight2, reservation_id)

    assert flight3.reservations[reservation_id].status == :confirmed
    assert flight3.seats["1A"].status == :confirmed
  end

  test "|Cancelar una reserva pendiente libera el asiento|", %{flight: flight} do
    {:ok, flight2, reservation_id} = Flight.reserve_seat(flight, 1, "1A")
    {:ok, flight3} = Flight.cancel_reservation(flight2, reservation_id)

    assert flight3.reservations[reservation_id].status == :cancelled
    assert flight3.seats["1A"].status == :available
  end

  test "|Imposibilidad de cancelar una reserva ya confirmada|", %{flight: flight} do
    {:ok, flight2, reservation_id} = Flight.reserve_seat(flight, 1, "1A")
    {:ok, flight3} = Flight.confirm_reservation(flight2, reservation_id)
    result = Flight.cancel_reservation(flight3, reservation_id)

    assert result == {:error, :already_confirmed}
  end

  test "|Expirar una reserva pendiente libera el asiento|", %{flight: flight} do
    {:ok, flight2, reservation_id} = Flight.reserve_seat(flight, 1, "1A")
    {:ok, flight3} = Flight.expire_reservation(flight2, reservation_id)

    assert flight3.reservations[reservation_id].status == :expired
    assert flight3.seats["1A"].status == :available
  end

  test "|Imposibilidad de expirar una reserva ya confirmada|", %{flight: flight} do
    {:ok, flight2, reservation_id} = Flight.reserve_seat(flight, 1, "1A")
    {:ok, flight3} = Flight.confirm_reservation(flight2, reservation_id)
    result = Flight.expire_reservation(flight3, reservation_id)

    assert result == {:error, :reservation_not_pending}
  end

  test "|Available_seats devuelve solo los asientos disponibles|", %{flight: flight} do
    {:ok, flight2, _} = Flight.reserve_seat(flight, 1, "1A")
    available = Flight.available_seats(flight2)

    assert length(available) == 8
    refute Enum.any?(available, fn s -> s.id == "1A" end)
  end

  test "|Dos pasajeros no pueden reservar el mismo asiento|", %{flight: flight} do
    {:ok, flight2, _} = Flight.reserve_seat(flight, 1, "2B")
    result = Flight.reserve_seat(flight2, 2, "2B")

    assert result == {:error, :seat_not_available}
  end
end
