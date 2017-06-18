defmodule TESIS do

  def tell(receiver, message) do
    IO.puts "[#{inspect self}] Sending #{message} to #{inspect receiver}"
    send receiver, {:ok, self, message}
  end

  def listen do
    IO.puts "[#{inspect self}] is listening"
    receive do
      {:ok, sender, message} ->
        IO.puts "[#{inspect self}] Received #{message} from #{inspect sender}"
    end
    listen
  end





end
