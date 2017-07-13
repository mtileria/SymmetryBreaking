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
      msg_counter: %{},
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


  def update_message_counter(map,count,round) do
    {actual_x, actual_y} = count

    case Map.get(map,round) do
      nil ->
        {actual_x, actual_y}
      {x,y} ->
        {actual_x, actual_y} = count
        {x + actual_x, y + actual_y}
  end
end

  def sum_messages (counter) do
    msg = Enum.reduce(Map.values(counter),0, fn(x,acc) ->
      {m,_} = x
      m + acc end)

      overhead = Enum.reduce(Map.values(counter),0, fn(x,acc) ->
        {_,n} = x
        n + acc end)

        {msg,overhead}
  end


  def set_values_test() do  ## for dummy example 0nodes file
    values = [0.4,0.3,0.1,0.5,0.2,0.6,0.7,0.8]
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

def run_master(state) do

  state =
    receive do

      {:test_values, values} ->  ## for dummy example
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

      {:complete,mis,active,sender,msg_count} ->
        # IO.puts ("Complete from #{inspect sender}, #{mis}, #{active}")
        state = %{state | count: state.count + 1}
        {num_msg,sync_overhead} = update_message_counter(state.msg_counter,msg_count,state.round)
        state = put_in(state, [:msg_counter,state.round], {num_msg,sync_overhead})
        cond  do
          active == false && mis == true ->  ## node is part of MIS
            state = %{state | mis: state.mis ++ [sender]}
            state = %{state | to_delete: state.to_delete + 1}
            state = %{state | new_mis: state.new_mis + 1}
          active == false && mis == false -> ## node is neighbor of node in MIS
            state = %{state | to_delete: state.to_delete + 1}
          true ->  ## node active for next round
            state = %{state | actives: state.actives ++ [sender]}
        end

        if state.count == state.active_size do
          IO.puts("ROUND #{state.round} FINISH!!! New In MIS #{state.new_mis}, next actives: #{length(state.actives)}, inactive: #{state.to_delete}, nodes remove not MIS: #{state.to_delete - state.new_mis}, msg: #{inspect Map.get(state.msg_counter,state.round)} ")
          state = %{state | active_size: length(state.actives)}
          state = %{state | round: state.round + 1}
          state = %{state | count: 0}
          state = %{state | to_delete: 0}
          state = %{state | new_mis: 0}
          case state.active_size == 0 do
            true ->
              {total_msg,total_overhead} = sum_messages (state.msg_counter)
              IO.puts("MIS complete: MIS number nodes: #{length(state.mis)}, Number rounds #{inspect state.round}
                , Number of messages #{total_msg} , extra msg: #{total_overhead}
                 network size: #{length(state.processes)}")
              state
            false ->
              Enum.each(state.actives, fn(pid) ->
                send(pid,{:update_topology})end)
                state
          end
        end
        state

        {:update_complete} ->
          state = %{state | count_topology: state.count_topology + 1}
          if state.count_topology == state.active_size do
            state = %{state | count_topology: 0}
            next_round = state.actives
            state = %{state | actives: []}
            Enum.each(next_round, fn(pid) ->
              send(pid,{:find_mis,:continue})end)
          end
          state

    end
    run_master(state)
  end
end
