defmodule B_controller do


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
    master_id = spawn(B_controller,:run_master,[init_master(:master)])
    case :global.register_name(:master,master_id) do
      :yes -> master_id
      :no -> :error
    end

    # load topology from file and spawn processes
    stream = File.stream!("/home/marcos/rhul/simulator/files/" <> Integer.to_string(n) <> "nodes.txt")
    p_names = String.split(List.first(Enum.take(stream, 1)))
    p_ids = for name <- p_names do
       SyncMisBeta.start(name,master_id)
    end
    send(master_id,{:add_processes_list,p_ids})
    add_edges_topology(n)
  end

  defp add_edges_topology(n) do
    # load edges from file and send list neighbors to every process
		# This is for Erdos Renyi edges
		# stream = File.stream!("/home/marcos/rhul/simulator/files/" <> Integer.to_string(n) <> "edges.txt")
		 # This is for SBM edges
		 stream = File.stream!("/home/marcos/rhul/simulator/files/connected/" <> Integer.to_string(n) <> "edges.txt")
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
			send(process_by_name(:master),{:spanning_tree,:start})
	end

	def start_mis() do
 		send(process_by_name(:master),{:search_mis,:start})
	end

  defp process_by_name (name) do
    case :global.whereis_name(name) do
      :undefined -> :undefined
      pid -> pid
    end
  end

	defp update_message_counter(map,count,round) do
		{actual_x, actual_y} = count
		case Map.get(map,round) do
			nil ->
				{actual_x, actual_y}
			{x,y} ->
				{x + actual_x, y + actual_y}
		end
	end

defp sum_messages (counter) do
	msg = Enum.reduce(Map.values(counter),0, fn(x,acc) ->
	 {m,_} = x
	 m + acc end)
	overhead = Enum.reduce(Map.values(counter),0, fn(x,acc) ->
		{_,n} = x
		n + acc end)
	{msg,overhead}
	end


	def save_results(n,data) do
    {:ok,file} = File.open("/home/marcos/rhul/simulator/results/connected/b_" <> Integer.to_string(n) <> "_results.log",[:append])
    IO.binwrite(file,data)
    File.close file
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

		{:kill_all} ->
			Enum.each(state.processes, fn(x) -> send x,{:kill} end)
			Process.exit(self, :exit)

    {:spanning_tree,:start} ->
      send hd(state.processes),{:spanning_tree,:root}
      state

		{:completed_node} ->
			#  IO.puts "rec #{state.tree_replies + 1}"
      state = %{state | tree_replies: state.tree_replies + 1}
      if state.tree_replies == length(state.processes) do
        IO.puts("Spanning Tree complete")
        state
      else
			  state
      end

		{:search_mis,:start} ->
			Enum.each(state.processes, fn dest ->
				send dest,{:find_mis,:init}end)
			state

	  {:complete,type,mis,active,sender,msg_count,round} ->
			state = %{state | count: state.count + 1}
			{num_msg,sync_overhead} = update_message_counter(state.msg_counter,msg_count,round)
			state = put_in(state, [:msg_counter,round], {num_msg,sync_overhead})
			state =
			cond  do
				type == :dummy ->
					state
				active == false && mis == true->  ## node is part of MIS
					state = %{state | mis: state.mis ++ [sender]}
					state = %{state | new_mis: state.new_mis + 1}
					state = %{state | inactives: state.inactives + 1}

				active  == false && mis == false -> ## node is neighbor of node in MIS
					state = %{state | not_mis: state.not_mis + 1}
					state = %{state | inactives: state.inactives + 1}

				active == true && mis == false ->  ## node will continue in next round
					state = %{state | actives: state.actives + 1}
			end

			state =
			if state.count == length(state.processes) do
				state = %{state | total_inactives: state.total_inactives + state.inactives}
				IO.puts("ROUND #{state.round} FINISH!!! New In MIS #{state.new_mis}, next actives: #{state.actives}, inactive: #{state.inactives}, nodes remove not MIS: #{state.not_mis}, msg: #{inspect Map.get(state.msg_counter,round)} ")
				state = %{state | count: 0}
				state = %{state | round: state.round + 1}
				state = %{state | new_mis: 0}
				state = %{state | actives: 0}
				state = %{state | inactives: 0}
				case length(state.mis) + state.not_mis == length(state.processes) do
						true ->
							{total_msg,total_overhead} = sum_messages (state.msg_counter)
							IO.puts("\n ****MIS complete*****
							MIS number nodes: #{length(state.mis)},Rounds #{inspect state.round} ,
							Number of messages: #{total_msg} , Sync overhead:#{total_overhead}
							network size: #{length(state.processes)}")
              # Uncomment the next line to save the results of the algorithm
              # save_results(length(state.processes),"#{length(state.mis)} #{inspect state.round} #{total_msg} #{total_overhead} #{length(state.processes)} \n")
							state
						false ->
							Enum.each(state.processes, fn(pid) ->
								send(pid,{:find_mis,:continue})end)
								state
				end
			else
				state
			end

		end
		run_master(state)
	end
end
