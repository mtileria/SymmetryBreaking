defmodule SimpleLeaderElection do


  def init_state(name,idp) do
    %{ name: name,
       id: idp,
       left: nil,
       leader: false,
     }
  end

  def start(name,idp) do
    pid = spawn(SimpleLeaderElection,:run, [init_state(name,idp)])
    case :global.register_name(name,pid) do
      :yes -> pid
      :no  -> :error
    end
  end

  def left_neighbor(left, my_pid) do
    send(my_pid,{:define_neighbor,left})
  end

  def start_leader_election(my_pid) do
    send(my_pid,{:send_left})
  end

  def run(state) do

    state = receive do

      {:define_neighbor,left} ->
        state = %{ state | left: left}

      {:send_left} ->
        send(state.left,{:election, state.id})
        state

       {:election, id_mayor} ->
         state =
         cond do
           id_mayor > state.id ->
             send(state.left,{:election,id_mayor})
             state
           id_mayor == state.id ->
             IO.puts("I am the leader #{state.name}")
             state =  %{ state | leader: true}
           id_mayor < state.id ->
             IO.puts("#{id_mayor} is not the leader in #{state.name}")
             state
         end



    end

    run(state)

  end

end
