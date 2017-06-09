@moduledoc """

  Synchronouos Simulation of Maximal Independet Set MIS


"""
defmodule MIS do

  def init_state(name, master) do
    %{ name: name,
       neighbors: [],
       n_size: 0,
       n_receive: 0,
       count: 0,
       master_id: master,
     }
  end

  def init_master(n) do
    %{
       processes: [],
       size: n,
       mis: [],
       round: 0,
       count: 0,
     }
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
    master_id = spawn(MIS,:run_master,[init_master(n)])
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
        process_by_name(node) end
      send(id_origin,{:add_neighborhs, ids_destination})
      end)
  end

  defp process_by_name (name) do
    case :global.whereis_name(name) do
      :undefined -> :undefined
      pid -> pid
    end
  end


  def find_MIS() do
    case :global.whereis_name(:master) do
      :undefined -> :undefined
      pid -> send(pid,{:start_mis})
    end
  end


  def run(state) do

    my_pid = self()
    :random.seed(:erlang.now)
    value = :rand.uniform(100)

    state = receive do

      {:add_neighborhs, ids_destinations} ->
        IO.puts "msg to #{inspect self} list: #{inspect ids_destinations}"
        state = %{state | neighbors: ids_destinations}


      {:start_mis} ->
        state
    end
  run (state)
  end

  def run_master(state) do
    state =
      receive do

        {:add_processes_list,p_ids} ->
          state = %{state | processes: p_ids}

          {:start_mis} ->
            for p_id <- state.processes do
              send(p_id,{:start_mis})
            end
            state
    end
    run_master(state)
  end
end
