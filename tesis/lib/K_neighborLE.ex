defmodule KneighborLE do

  def init_state(name,idp) do
    %{ name: name,
       id: idp,
       left: nil,
       right: nil,
       k: 0,
       leader: false,
       left_reply: false,
       right_reply: false,
     }
  end

  def start(name,idp) do
    pid = spawn(KneighborLE,:run, [init_state(name,idp)])
    case :global.register_name(name,pid) do
      :yes -> pid
      :no  -> :error
    end
  end

  def left_right_neighbors(left, right, my_pid) do
    send(my_pid,{:define_neighbors,left,right})
  end

  def start_leader_election(my_pid) do
    send(my_pid,{:send_probe})
  end

  def run(state) do

    state = receive do

      {:define_neighbors,left,right} ->
        IO.puts("In #{state.name} msg-> {:define_neighbors,left = #{inspect left},right = #{inspect right}}")
        state = %{ state | left: left}
        state = %{ state | right: right}

      {:send_probe} ->
        IO.puts("In #{state.name} msg-> {:send_probe in #{inspect state.id}}")
        state = %{ state | k: 1}
        send(state.left,{:election, state.id, state.k, :left})
        send(state.right,{:election, state.id, state.k, :right})
        state

       {:election, id_mayor, k, direction} ->
         IO.puts("In #{state.name} msg-> {:election, id_mayor = #{inspect id_mayor}, k = #{k}, direction=#{direction}}")
         k = k - 1
         state =
         cond do
           id_mayor > state.id ->
             cond do
               k == 0 ->
                 dest = case direction do :left -> state.right; :right -> state.left end
                 send(dest,{:reply, id_mayor,direction})
                 state
               k > 0 ->
                 dest = case direction do :left -> state.left; :right -> state.right end
                 send(dest,{:election,id_mayor,k,direction})
                 state
              end

           id_mayor == state.id ->
             IO.puts("I am the leader #{state.name}")
             state =  %{ state | leader: true}
         end


         {:reply, id_mayor,direction} ->
           IO.puts("In #{state.name} msg-> {:reply, id_mayor #{inspect id_mayor} direction=#{direction}}")
           dest = case direction do :left -> state.right; :right -> state.left end
           state =
           cond do
             id_mayor == state.id ->

               state =
                 if direction == :left do
                   state = %{state | left_reply: true}
                 else
                   state = %{state | right_reply: true}
                 end

               state =
               cond do
                 state.right_reply == true && state.left_reply == true ->
                   state =  %{state | k: state.k*2}
                   state = %{state | left_reply: false}
                   state = %{state | right_reply: false}
                   send(state.left,{:election, state.id, state.k, :left})
                   send(state.right,{:election, state.id, state.k, :right})
                   state
                 true ->
                   state
               end


             id_mayor != state.id ->
               send(dest,{:reply,id_mayor, direction})
               state
           end
    end
   run(state)

  end

end

# p0 = KneighborLE.start("p0",50)
# p1 = KneighborLE.start("p1",100)
# p2 = KneighborLE.start("p2",90)
# p3 = KneighborLE.start("p3",70)
# p4 = KneighborLE.start("p4",20)
#
# KneighborLE.left_right_neighbors(p1,p4,p0)
# KneighborLE.left_right_neighbors(p2,p0,p1)
# KneighborLE.left_right_neighbors(p1,p3,p2)
# KneighborLE.left_right_neighbors(p4,p2,p3)
# KneighborLE.left_right_neighbors(p0,p3,p4)
#
# KneighborLE.start_leader_election(p1)
