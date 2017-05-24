defmodule CausalBC do

  @moduledoc """

    Implementation of Causal Broadcast



  """

  def init_state(name,participants,vclock,p) do

    %{ name: name,

       participants: participants,

       vt: vclock,

       i: p,

       pendings: []   #set of {mens,vt,j}

     }

  end



  def start(name,participants,vclock,p) do

    pid = spawn(CausalBC,:run, [init_state(name,participants,vclock,p)])

    case :global.register_name(name,pid) do

      :yes -> pid

      :no  -> :error

    end

  end



  def bc_send(msg,origin), do: send(origin,{:input,:bc_send,msg})



  @doc """

    Check the following condition

    w[k] <= vt[k]  for all k != j

  """

  def check(w, v, j) do

    w = Tuple.to_list(w)

    v = Tuple.to_list(v)

    Enum.zip(w, v)

    |> Enum.with_index

    |> Enum.all?(fn {{ww, vv}, k} -> k == j || ww <= vv end)

  end



  @doc """

    Check the following condition

    w[j] = vt[j] + 1

  """

  def check_vt(w,j,state), do: elem(w,j) == elem(state.vt,j) + 1



  def remove_pending(state,[]), do: []

  def remove_pending(state,[{p_origin,r_msg,w_prime,j_prime} | pending]) do

    if check(w_prime, state.vt, j_prime) and check_vt(w_prime, j_prime, state) do

      [ {p_origin,r_msg,w_prime,j_prime} | remove_pending(state,pending) ]

    else

      remove_pending(state,pending)

    end

  end



  @doc """

    Function to update state, perform:

    vt[j] = v[j] + 1

    delete messages from pendings

  """

  def update_vc(state,[]), do: state

  def update_vc(state,[{p_origin,r_msg,w_prime,j_prime} | ready_msgs]) do

    state = %{ state | vt: put_elem(state.vt, j_prime , elem(state.vt,j_prime) + 1)}

    state = %{ state | pendings: state.pendings -- [{p_origin,r_msg,w_prime,j_prime}]}

    update_vc(state,ready_msgs)

  end



  def run(state) do

    my_pid = self()

    state = receive do

      {:input,:bc_send,msg} ->

        v = state.vt

        v = put_elem(v, state.i, elem(v,state.i) + 1)

        state = %{ state | vt: v}

        send(my_pid,{:output,:bc_receive,msg,self()})                   # send bc-receive to myself

        for p <- state.participants do

          case :global.whereis_name(p) do

            :undefined -> :undefined

            pid -> send(pid,  {:bc_msg,my_pid,msg, state.vt, state.i})

          end

        end

        state



      {:output,:bc_receive,msg,origin} ->

        IO.puts("CausalBC  in #{inspect state.name} message: #{inspect msg}}")

        state



      {:bc_msg,origin,msg,w,j} ->

        if (state.i != j) do

          state = %{state | pendings: state.pendings ++ [{origin,msg,w,j}]}

          ready_msgs = remove_pending(state,state.pendings)

          state = update_vc(state,ready_msgs)

          for {x,y,z,t} <- ready_msgs, do: send(x,{:output,:bc_receive,y,my_pid})

        else

          IO.puts ("BC already receive in #{inspect state.name}")

        end

        state

    end                                                        #  end of receive

    run(state)

  end                                                           # end of run

end                                                             # end of module





####   Test for CausalBroadcast   ############33
