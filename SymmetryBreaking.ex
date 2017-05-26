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
        IO.puts("state: #{inspect state}")
        state

      {:send_left} ->
        IO.puts ("llegue hasta aca")
        send(state.left,{:election, state.id})
        state

       {:election, id_mayor} ->
         state =
         cond do
           id_mayor > state.id ->
             IO.puts("id_mayor greater than my id #{state.name}")
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


p0 = SimpleLeaderElection.start("p0",50)
p1 = SimpleLeaderElection.start("p1",100)
p2 = SimpleLeaderElection.start("p2",90)
p3 = SimpleLeaderElection.start("p3",70)
p4 = SimpleLeaderElection.start("p4",20)

SimpleLeaderElection.left_neighbor(p1,p0)
SimpleLeaderElection.left_neighbor(p2,p1)
SimpleLeaderElection.left_neighbor(p3,p2)
SimpleLeaderElection.left_neighbor(p4,p3)
SimpleLeaderElection.left_neighbor(p0,p4)

SimpleLeaderElection.start_leader_election(p4)
