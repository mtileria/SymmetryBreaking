defmodule SimpleLeaderElection do


  def init_state(name) do

    %{ name: name,

       left: nil,

       right: nil,

     }

  end

  def start(name) do

    pid = spawn(SimpleLeaderElection,:run, [init_state(name)])

    case :global.register_name(name,pid) do

      :yes -> pid

      :no  -> :error

    end
  end

  def left_right_neighbors(left,right, my_pid) do
    send(my_pid,{:define_neighbors,left,right})
  end

  def run(state) do

  #  my_pid = self()

    state = receive do

      {:define_neighbors,left,right} ->
        state = %{ state | left: left}
        state = %{ state | right: right}
        IO.puts("state: #{inspect state}")


    end

    run(state)

  end



end
