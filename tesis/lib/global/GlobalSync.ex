defmodule GlobalSync do


  def init_master(n) do
    %{
      processes: [],
      actives: [],
      to_delete: 0,
      active_size: n,
      mis: [],
      round: 0,
      count: 0,
      count_topology: 0,
      new_mis: 0,
      not_mis: 0,
      not_names: [],
      msg_counter: %{},
      topology: %{},
      edges: 0,
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
    master_id = spawn(GlobalSync,:run_master,[GlobalSync.init_master(n)])
    case :global.register_name(:master,master_id) do
      :yes -> master_id
      :no -> :error
    end
    # load topology from file and spawn processes
    stream = File.stream!("/home/marcos/rhul/tesis/files/" <> Integer.to_string(n) <> "nodes.txt")
    p_names = String.split(List.first(Enum.take(stream, 1)))
    p_ids = for name <- p_names do
      pid = spawn(MIS,:run, [MIS.init_state(name,master_id)])
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
    #stream = File.stream!("/home/marcos/rhul/generator/topologies/connected/" <> Integer.to_string(n) <> "edges.txt")

    Enum.each(stream, fn(x) ->
      nodes = String.split(x)
      origin = List.first(nodes)
      nodes = List.delete_at(nodes, 0)
      if length(nodes) == 0, do: IO.puts(origin)
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
    {:ok,file} = File.open("/home/marcos/rhul/tesis/results/connected/g1_erdos_" <> Integer.to_string(n) <> "_results.txt",[:append])
    IO.binwrite(file,data)
    File.close file
  end

  def save_topology(data,round) do
    {:ok, file} = File.open "/home/marcos/rhul/output/graph" <> round <> ".txt", [:write]
    Enum.each(data, fn {x,y} ->
        IO.binwrite(file, x <> ": " <> Enum.join(y," ") <> "\n")
      end)
      File.close file
  end

  def save_topology_formated(data,round,nodes) do
    {:ok, file} = File.open "/home/marcos/rhul/output/round" <> round <> ".txt", [:write]
    data = List.flatten(data)
    edges = Integer.to_string(Enum.count(data))
    IO.binwrite(file, nodes <> " " <> edges <> "\n")
    Enum.each(data, fn {x,y} ->
        IO.binwrite(file, x <> " " <> y <> "\n")
      end)
      File.close file
  end

  def format_topology(topology) do
    for {key,value} <- topology, do:
      for x <- value, do:
        {key,x}
  end


  def big_test() do
    stream = File.stream!("/home/marcos/list.txt") |> Stream.map(&String.trim_trailing/1) |> Enum.to_list
    split = String.split(List.first(stream))
    list =
    for value <- split do
      String.to_float(value)
    end
    if length(list) == 8192 do
      send(process_by_name(:master),{:test_values,list})
    else
      IO.puts "#{length(list)}"
      :error
    end
  end



  def set_values_test() do  ## for dummy example 0nodes file
    values = [0.4,0.3,0.1,0.5,0.2,0.6,0.7,0.8]
    #values = [0.12, 0.94, 0.03, 0.08, 0.94, 0.82, 0.54, 1.0, 0.62,0.26, 0.71, 0.57, 0.38, 0.5, 0.63, 0.65]
    case :global.whereis_name(:master) do
      :undefined -> :undefined
      pid -> send(pid,{:test_values, values})
    end
  end

  def start_mis() do
    case :global.whereis_name(:master) do
      :undefined -> :undefined
      pid -> send(pid,{:start_mis})
    end
  end

  def finish_simulation() do
      send(process_by_name(:master),{:kill_all})
  end

def run_master(state) do

  state =
    receive do

      {:test_values, values} ->  ## for dummy and not so dummy example
        tupleEnum = Enum.zip(state.processes, values)
        Enum.each(tupleEnum, fn {x,y} -> send(x,{:set_value,y})end)
        state


      {:add_processes_list,p_ids} ->
        state = %{state | processes: p_ids}
        state = %{state | active_size: length(p_ids)}

      {:start_mis} ->
        Enum.each(state.processes, fn(pid) ->
          send(pid,{:find_mis,:initial})end)
        state

      {:kill_all} ->
        Enum.each(state.processes, fn(x) -> send x,{:kill} end)
        Process.exit(self, :exit)

      {:complete,mis,active,sender,name,msg_count} ->
        # IO.puts ("Complete from #{name}, mis:#{mis}, active:#{active}")
        state = %{state | count: state.count + 1}
        {num_msg,sync_overhead} = update_message_counter(state.msg_counter,msg_count,state.round)
        state = put_in(state, [:msg_counter,state.round], {num_msg,sync_overhead})

         state =
          cond  do
          active == false && mis == true ->  ## node is part of MIS
            state = %{state | mis: state.mis ++ [name]}
            state = %{state | to_delete: state.to_delete + 1}
            state = %{state | new_mis: state.new_mis + 1}
          active == false && mis == false -> ## node is neighbor of node in MIS
            state = %{state | to_delete: state.to_delete + 1}
            state = %{state | not_mis: state.not_mis + 1}
            state= %{state | not_names: state.not_names ++ [name]}
          # true ->  ## node active for next round
          active == true && mis == false ->
            state = %{state | actives: state.actives ++ [sender]}
          active == true && mis == true ->
            IO.puts "Error fatal"
            state
        end


        if state.count == state.active_size do
          IO.puts("ROUND #{state.round} FINISH!!! New In MIS #{state.new_mis}: , next actives: #{length(state.actives)}, inactive: #{state.to_delete}, nodes remove not MIS: #{state.not_mis}, msg: #{inspect Map.get(state.msg_counter,state.round)} ")
          # IO.puts("ROUND #{state.round} FINISH!!! New In MIS #{state.new_mis}: #{inspect state.mis}, next actives: #{length(state.actives)}, inactive: #{state.to_delete}, \n nodes remove not MIS: #{state.not_mis}: #{inspect state.not_names}")#, msg: #{inspect Map.get(state.msg_counter,state.round)} ")
          state = %{state | active_size: length(state.actives)}
          state = %{state | round: state.round + 1}
          state = %{state | count: 0}
          state = %{state | to_delete: 0}
          state = %{state | new_mis: 0}
          state = %{state | not_mis: 0}
          case state.active_size == 0 do
            true ->
              {total_msg,total_overhead} = sum_messages (state.msg_counter)
              IO.puts("\n**** MIS complete ******
              MIS number nodes: #{length(state.mis)}, Rounds #{inspect state.round}
                , Number of messages #{total_msg} , Sync overhead: #{total_overhead}
                 network size: #{length(state.processes)}")
                 save_results(length(state.processes),"#{length(state.mis)} #{inspect state.round} #{total_msg} #{total_overhead} #{length(state.processes)} \n")
                #  save_results([length(state.mis),state.round,total_msg,total_overhead,length(state.processes)])

              state

            false ->
              Enum.each(state.actives, fn(pid) ->
                send(pid,{:update_topology})end)
                state
          end
        else
          state
        end


        {:update_complete,name,neighbours} ->
          state = %{state | count_topology: state.count_topology + 1}
          state =
          if length(neighbours) > 0, do:
             state = %{state | topology: Map.put(state.topology, name, neighbours)},
            else: state
          if state.count_topology == state.active_size do
            topology_edges = format_topology(state.topology)
            r = Integer.to_string(state.round)
            nodes = Integer.to_string(Enum.count(state.processes))
            save_topology_formated(topology_edges,r,nodes)
            state = %{state | count_topology: 0}
            next_round = state.actives
            state = %{state | actives: []}
            state = %{state | topology: %{}}
            Enum.each(next_round, fn(pid) -> send(pid,{:find_mis,:continue})end)
            state
          else
            state
          end

    end
    run_master(state)
  end
end
