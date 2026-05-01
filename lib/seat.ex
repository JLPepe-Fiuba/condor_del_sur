defmodule Seat do
  defstruct [:id, :row, :column, status: :available]

  # status puede ser :available :reserved :confirmed
end
