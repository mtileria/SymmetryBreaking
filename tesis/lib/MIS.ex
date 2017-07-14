defmodule MIS do
  @moduledoc """

  Synchronouos Simulation of Maximal Independet Set MIS


  """
  def init_state(name, master) do
    %{ name: name,
    active: true,
    value: :rand.uniform(),
    neighbors: [],
    n_size: 0,
    n_receive: 0,
    to_delete: [],
    count: 0,
    ack: 0,
    safe_count: 0,
    master_id: master,
    mis: false,
    msg_count: 0,
  }
end


defp notify_neighbors(destinations,msg) do
  {text,mis_status} = msg
  Enum.each(destinations,fn(dest) -> send(dest,{text,mis_status})end)
end


def run(state) do
  my_pid = self()
  state = receive do


    {:add_neighborhs, ids_destinations} ->
      state = %{state | neighbors: ids_destinations}
      state = %{state | n_size: length(ids_destinations)}

    {:find_mis,x} ->  # x = :continue || :initial

     state =
      if x == :continue do
          state = %{state | value: :rand.uniform()}
      else
          state
      end

      state =
      case state.n_size > 0 do
        true ->
          Enum.each(state.neighbors, fn (node) ->
            send(node,{:value,state.value,my_pid})end)
            state
        false ->
          # IO.puts "In #{inspect my_pid}, I am alone, complete"
          state = %{state | active: false}
          state = %{state | mis: true}
          send(state.master_id,{:complete,state.mis,state.active,my_pid,{0,0}})
          state
        end


    {:value,value,sender,} ->
      #IO.puts ("In #{inspect my_pid}  value :#{inspect sender}")
        state = %{state | n_receive: state.n_receive + 1}
        state = if (state.value < value),
          do: state = %{state | count: state.count + 1}, else: state
        state =
          if state.n_receive == state.n_size do
            case state.count == state.n_size do
               true->  ## I am mis member
                state = %{state | mis: true}
                state = %{state | active: false}
                state = %{state | count: 0}
               false -> ## All msg receive and not mis member
                 state = %{state | n_receive: 0}
                 state = %{state | count: 0}
            end
        else  ## Not receive all msg yet
          state
        end
        send(sender,{:ack})
        state


    {:ack} ->
  #  IO.puts ("In #{inspect my_pid} recv ack from : #{inspect sender}")
      state = %{state | ack: state.ack + 1}
      state =
      if state.ack == state.n_size do
          # IO.puts ("In #{inspect my_pid} recv all ack, size: #{state.n_size}")
          case state.mis == true do
            true ->
              notify_neighbors(state.neighbors,{:safe,:mis_member})
              state
            false ->   # not mis member but receive all ack
              state = %{state | ack: 0}
              notify_neighbors(state.neighbors,{:safe,:not_mis_member})
              state
          end
      else
        state
      end


        {:safe,neighbor_mis} ->
        #  IO.puts ("In #{inspect my_pid} recv safe from : #{inspect origin}, and #{neighbor_mis}, #{state.safe_count + 1}")
          state = %{state | safe_count: state.safe_count + 1}
          state =
          if neighbor_mis == :mis_member, do:
              state = %{state | active: false}, else: state
          state =
          if state.safe_count == state.n_size do
              state = %{state | safe_count: 0}
              send(state.master_id,{:complete,
                state.mis,state.active,my_pid,{4*state.n_size,3*state.n_size}})
              state
          else
            state
          end


          {:update_topology} ->
              Enum.each(state.neighbors,fn(dest) ->
                send(dest,{:status_request, my_pid})end)
            state

          {:status_request, sender} ->
            #IO.puts ("In #{inspect my_pid} recv update_netw from : #{inspect sender}")
            send(sender,{:status_reply,my_pid,state.active})
            state

          {:status_reply,sender,active} ->
            # IO.puts ("In #{inspect my_pid} recv update_reply from : #{inspect sender}, status: #{active}
            # count: #{state.count}, size: #{state.n_size}")
            state = %{state | count: state.count + 1}
            state =
            cond do
              active == false ->
                state = %{state | to_delete: state.to_delete ++ [sender]}
              active == true ->
                state
            end
            state =
            if state.count == state.n_size do
              # IO.puts "recv all update_reply in #{inspect my_pid}, size neigh: #{state.n_size}"
                num_msg = state.n_size
                state = %{state | neighbors: state.neighbors -- state.to_delete}
                state = %{state | to_delete: []}
                state = %{state | n_size: length(state.neighbors)}
                state = %{state | count: 0}
                send(state.master_id,{:update_complete})
                state
            else
              state
            end


    end
    run (state)
  end
end
