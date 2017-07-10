defmodule MIS do
  @moduledoc """

  Synchronouos Simulation of Maximal Independet Set MIS


  """
  def init_state(name, master) do
    state = %{ name: name,
    active: true,
    neighbors: [],
    n_size: 0,
    n_receive: 0,
    to_delete: [],
    value: nil,
    round: 0,
    count: 0,
    ack: 0,
    safe_count: 0,
    master_id: master,
    mis: false,
    msg_count: 0,
  }
  state = %{state | value: :rand.uniform()}
end

@doc """

This function spawn 2 kind of process
1- Master process that manage the topology and control rounds
2- Nodes that implement the distributed algorithm

The topology is read from files and spawn processes with name according
the files.

n is the number of nodes in the network
range is [64,8192] incrementing in power of 2


"""
def start_nodes (n) do
  # create master process
  master_id = spawn(Master,:run_master,[Master.init_master(n)])
  case :global.register_name(:master,master_id) do
    :yes -> master_id
    :no -> :error
  end
  # load topology from file and spawn processes
  stream = File.stream!("/home/marcos/rhul/tesis/files/" <> Integer.to_string(n) <> "nodes.txt")
  p_names = String.split(List.first(Enum.take(stream, 1)))
  p_ids = for name <- p_names do
    pid = spawn(MIS,:run, [init_state(name,master_id)])
    case :global.register_name(name,pid) do
      :yes ->
        pid
      :no -> :error
    end
  end
  send(master_id,{:add_processes_list,p_ids})
  add_edges_topology(n)
end

defp add_edges_topology(n) do
  # load edges from file and send list neighbors to every process
  stream = File.stream!("/home/marcos/rhul/tesis/files/" <> Integer.to_string(n) <> "edges.txt")
  Enum.each(stream, fn(x) ->
    nodes = String.split(x)
    origin = List.first(nodes)
    nodes = List.delete_at(nodes, 0)
    id_origin = process_by_name(origin)
    ids_destination =
      for node <- nodes do
        process_by_name(node)
      end
        send(id_origin,{:add_neighborhs, ids_destination})
   end)
  end

defp process_by_name (name) do
  case :global.whereis_name(name) do
    :undefined -> :undefined
    pid -> pid
  end
end

defp notify_neighbors(origin, destinations,msg) do
  {text,mis_status} = msg
  Enum.each(destinations,fn(dest) -> send(dest,{text,origin,mis_status})end)
end

def find_MIS() do
  case :global.whereis_name(:master) do
    :undefined -> :undefined
    pid -> send(pid,{:start_mis})
  end
end




def run(state) do
  my_pid = self()
  state = receive do


    {:add_neighborhs, ids_destinations} ->
      state = %{state | neighbors: ids_destinations}
      state = %{state | n_size: length(ids_destinations)}

    {:find_mis,x} ->  # x = :continue || :initial

      state = %{state | round: state.round + 1}
      if x == :continue do
          # IO.puts "find_mis in #{inspect my_pid}, neighbor: #{inspect state.neighbors}"
          state = %{state | value: :rand.uniform()}
      else
          state
      end


      case state.n_size > 0 do
        true ->
          Enum.each(state.neighbors, fn (node) ->
            send(node,{:value,state.value,my_pid,state.round})end)
            state
        false ->
          # IO.puts "In #{inspect my_pid}, I am alone, complete"
          state = %{state | active: false}
          state = %{state | mis: true}
          send(state.master_id,{:complete,state.mis,state.active,my_pid,0})
          state
        end
        state

    {:value,value,sender,round} ->
      #IO.puts ("In #{inspect my_pid}  value :#{inspect sender}")
        state = %{state | n_receive: state.n_receive + 1}
        if (state.value < value), do: state = %{state | count: state.count + 1}, else: state
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
        send(sender,{:ack,my_pid})
        state


    {:ack,sender} -> # sender,
  #  IO.puts ("In #{inspect my_pid} recv ack from : #{inspect sender}")
      state = %{state | ack: state.ack + 1}
      if state.ack == state.n_size do
          # IO.puts ("In #{inspect my_pid} recv all ack, size: #{state.n_size}")
          case state.mis == true do
            true ->
              notify_neighbors(my_pid,state.neighbors,{:safe,:mis_member})
            false ->   # not mis member but receive all ack
              state = %{state | ack: 0}
              notify_neighbors(my_pid,state.neighbors,{:safe,:not_mis_member})
              state
          end
      end
      state

#   send(state.master_id,{:complete,:mis_member,my_pid,state.neighbors,length(state.neighbors)})

        {:safe,origin,neighbor_mis} ->
        #  IO.puts ("In #{inspect my_pid} recv safe from : #{inspect origin}, and #{neighbor_mis}, #{state.safe_count + 1}")
          state = %{state | safe_count: state.safe_count + 1}
          cond  do
            neighbor_mis == :mis_member -> # complete round adn neighbor is MIS member
              state = %{state | active: false}
            true ->   # complete round but neighbor is not mis member
              state
          end
          if state.safe_count == state.n_size do
              state = %{state | safe_count: 0}
              send(state.master_id,{:complete,state.mis,state.active,my_pid,state.n_size})
              state
          end
          state

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
            cond do
              active == false ->
                state = %{state | to_delete: state.to_delete ++ [sender]}
              active == true ->
                state
            end

            if state.count == state.n_size do
              # IO.puts "recv all update_reply in #{inspect my_pid}, size neigh: #{state.n_size}"
                num_msg = state.n_size
                state = %{state | neighbors: state.neighbors -- state.to_delete}
                state = %{state | to_delete: []}
                state = %{state | n_size: length(state.neighbors)}
                state = %{state | count: 0}
                send(state.master_id,{:update_complete,my_pid,state.n_size})
                state
            end
            state

    end
    run (state)
  end
end
