defmodule BetaController do


	def init_master(name) do
		%{
		  name: name,
		  processes: [],
      mis: [],
		  count: 0,
		  tree_replies: 0,
      round: 0,
      not_mis: 0,
      count_replies: 0,
      new_mis: 0,
      actives: 0,
      inactives: 0,
      total_inactives: 0,
      msg_counter: %{},
		  }
	end

    def start_nodes(n) do
    # create master process
    master_id = spawn(BetaController,:run_master,[init_master(:master)])
    case :global.register_name(:master,master_id) do
      :yes -> master_id
      :no -> :error
    end

    # load topology from file and spawn processes
    stream = File.stream!("/home/marcos/rhul/tesis/files/" <> Integer.to_string(n) <> "nodes.txt")
    p_names = String.split(List.first(Enum.take(stream, 1)))
    p_ids = for name <- p_names do
       SyncMisBeta.start(name,master_id)
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
          {process_by_name(node),process_by_name("Sync-"<>node)}
        end
      map_destinations = Enum.into(ids_destination, %{})
      send(id_origin,{:add_neighbors, map_destinations}) end)
    end

    def finish_simulation() do
        send(process_by_name(:master),{:kill_all})
    end

	def spanning_tree() do
		case :global.whereis_name(:master) do
			:undefined -> :error
			pid -> send pid,{:spanning_tree,:start}
		end
	end

	def start_mis() do
		case :global.whereis_name(:master) do
			:undefined -> :error
			pid -> send pid, {:search_mis,:start}
		end
	end

  defp process_by_name (name) do
    case :global.whereis_name(name) do
      :undefined -> :undefined
      pid -> pid
    end
  end



	def run_master (state) do

	state =
	receive do

		{:test_values, values} ->  ## for dummy example "0nodes"
			tupleEnum = Enum.zip(state.processes, values)
			Enum.each(tupleEnum, fn {x,y} -> send(x,{:set_value,y})end)
			state

		{:add_processes_list,p_ids} ->
			state = %{state | processes: p_ids}

    {:spanning_tree,:start} ->
      send hd(state.processes),{:spanning_tree,:root}
      state

		{:completed_node} ->
      state = %{state | tree_replies: state.tree_replies + 1}
      if state.tree_replies == length(state.processes) do
        IO.puts("Spanning Tree complete")
        state
      else
			  state
      end

		{:search,:mis} ->
			Enum.each(state.processes, fn dest ->
				send dest,{:search,:init}end)
			state

		end
		run_master(state)
	end
end
