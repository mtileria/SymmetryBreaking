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
    buffer: [],
    member: [],
    to_add: []
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

    {:kill} ->
      Process.exit(my_pid,:kill)

    {:set_value,y} ->
      state = %{state | value: y}
      state

    {:find_mis,x} ->  # _ por x = :continue || :initial

     state =
      if x == :continue do
          state = %{state | value: :rand.uniform()}
      else
          state
      end
      state = %{state | buffer: []}
      state = %{state | member: []}
      state =
      case state.n_size > 0 do
        true ->
          Enum.each(state.neighbors, fn (node) ->
            send(node,{:value,state.value,my_pid})end)
            state
        false ->
          state = %{state | active: false}
          state = %{state | mis: true}
          send(state.master_id,{:complete,state.mis,state.active,my_pid,state.name,{0,0}})
          state
        end


    {:value,value,sender} ->
      #IO.puts ("In #{inspect my_pid}  value :#{inspect sender}")
        state = %{state | n_receive: state.n_receive + 1}
        state = %{state | buffer: state.buffer ++ [value]}
        state =
          if state.n_receive == state.n_size do
            minimum = Enum.all?(state.buffer, fn(x) -> state.value < x  end)
            case minimum == true do
               true->  ## I am mis member
                state = %{state | mis: true}
               false -> ## All msg receive and not mis member
                 state = %{state | n_receive: 0}
            end
          else  ## Not receive all msg yet
            state
          end
        send(sender,{:ack})
        state


    {:ack} ->
      state = %{state | ack: state.ack + 1}
      state =
      if state.ack == state.n_size do
          case state.mis == true do
            true ->
              notify_neighbors(state.neighbors,{:safe,:mis_member})
              state
            false ->
              state = %{state | ack: 0}
              notify_neighbors(state.neighbors,{:safe,:not_mis_member})
              state
          end
      else
        state
      end


        {:safe,neighbor_mis} ->
            state = %{state | safe_count: state.safe_count + 1}
            state = %{state | member: state.member ++ [neighbor_mis]}

            if state.safe_count == state.n_size do
                state = %{state | safe_count: 0}
                is_neigbour_mis = Enum.any?(state.member, fn(x) -> x == :mis_member end)
                if (state.mis == true or is_neigbour_mis == true)  do
                    state = %{state | active: false}
                    send(state.master_id,{:complete,state.mis,state.active,my_pid,
                        state.name,{2*state.n_size,3*state.n_size + 2}})
                    state
                else
                  send(state.master_id,{:complete,state.mis,state.active,my_pid,
                    state.name,{2*state.n_size,3*state.n_size + 2}})
                  state
                end
            else
              state
            end



          {:update_topology} ->
              Enum.each(state.neighbors,fn(dest) ->
                send(dest,{:status_request, my_pid})end)
            state

          {:status_request, sender} ->
            send(sender,{:status_reply,my_pid,state.active,String.slice(state.name,1..10)})
            state

          {:status_reply,sender,active,name} ->
            state = %{state | count: state.count + 1}
            state =
            cond do
              active == false ->
                state = %{state | to_delete: state.to_delete ++ [sender]}
              active == true ->
                state = %{state | to_add: state.to_add ++ [name]}
            end
            state =
            if state.count == state.n_size do
                num_msg = state.n_size
                state = %{state | neighbors: state.neighbors -- state.to_delete}
                state = %{state | to_delete: []}
                state = %{state | n_size: length(state.neighbors)}
                state = %{state | count: 0}
                send(state.master_id,{:update_complete, String.slice(state.name,1..10),state.to_add})
                state = %{state | to_add: []}

                state
            else
              state
            end
    end
    run (state)
  end
end
