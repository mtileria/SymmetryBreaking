defmodule MIS do
  @moduledoc """

  Synchronouos Simulation of Maximal Independet Set MIS


  """
  def init_state(name, master) do
    state = %{ name: name,
    neighbors: [],
    value: nil,
    round: 0,
    n_size: 0,
    n_receive: 0,
    count: 0,
    ack: 0,
    master_id: master,
    mis: false,
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
      :yes -> pid
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
      IO.puts " origin #{inspect origin}, destinations : #{inspect ids_destination}"
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
  for dest <- destinations do
    send(dest,{msg,origin}) end
end


def find_MIS() do
  case :global.whereis_name(:master) do
    :undefined -> :undefined
    pid -> send(pid,{:start_mis})
  end
end

def set_values_test() do
  values = [0.4,0.3,0.1,0.5,0.2]
  case :global.whereis_name(:master) do
    :undefined -> :undefined
    pid -> send(pid,{:test_values, values})
  end
end


def run(state) do
  my_pid = self()
  state = receive do

    {:set_value, y} ->
      state = %{state | value: y}
      IO.puts("Initial: #{state.name}: #{state.value}")
      state

    {:add_neighborhs, ids_destinations} ->
      IO.puts "msg to #{inspect self} list: #{inspect ids_destinations}"
      state = %{state | neighbors: ids_destinations}
      state = %{state | n_size: length(ids_destinations)}


    {:find_mis,x} ->
      if x == :continue, do: state = %{state | value: :rand.uniform()}
      IO.puts ":find_mis in #{inspect self}, value: #{state.value}}"
      state = %{state | round: state.round + 1}
      Enum.each(state.neighbors, fn (node) ->
        send(node,{:value,state.value,my_pid,state.round})end)
      state

    {:value,value,sender,round} ->
      IO.puts ":value-recv in #{inspect self}: #{inspect value} from #{inspect sender}"
      state = %{state | n_receive: state.n_receive + 1}
      if (state.value < value), do: state = %{state | count: state.count + 1}

      if state.n_receive == state.n_size do
          cond do
            state.count == state.n_size ->
              state = %{state | mis: true}
            true ->
              state = %{state | n_receive: 0}
              state = %{state | count: 0}
        end
      else
        state
      end
      ### probably send ACK here
      send(sender,{:ack,my_pid,round})
      state

    {:ack,sender,round} -> # sender,round
      IO.puts ":ack-recv in #{inspect self}: from #{inspect sender} in round #{round}"
      state = %{state | ack: state.ack + 1}
      case state.ack == state.n_size do
        true ->
          cond do
            state.mis == true ->
              send(state.master_id,{:mis_member,my_pid,state.neighbors})
              notify_neighbors(my_pid,state.neighbors,:mis_member)
              send(state.master_id,{:complete,my_pid,state.round})
              state
            true ->   # not mis member but complete round
              send(state.master_id,{:complete,my_pid,state.round})
              state
           end
        false ->     #not receive all ack yet ->  nothing
          state
        end

    {:mis_member, sender} ->
      IO.puts ":mis_member-recv in #{inspect self}: from #{inspect sender}"
      state = %{state | neighbors: state.neighbors -- [sender] }
      notify_neighbors(my_pid,state.neighbors,:not_mis_member)
      state

    {:not_mis_member,sender} ->
      IO.puts ":not_mis_member-recv in #{inspect self}: from #{inspect sender}"
      state = %{state | neighbors: state.neighbors -- [sender] }
    end
    run (state)
  end
end
