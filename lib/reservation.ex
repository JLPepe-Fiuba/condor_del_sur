defmodule Reservation do
  defstruct [:id, :passenger_id, :seat_id, :created_at, status: :pending]

  # status puede ser :pending :confirmed :cancelled :expired
end
