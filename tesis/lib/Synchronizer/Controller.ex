defmodule Controller do


  def init_master(name) do
    %{
      name: name,
      processes: [],
      mis: [],
      round: 0,
      to_delete: [],
      msg_count: %{send: 0, control: 0},
    }
  end

def start_nodes (n) do
  # create master process
  master_id = spawn(Controller,:run_master,[init_master(:master)])
  case :global.register_name(:master,master_id) do
    :yes -> master_id
    :no -> :error
  end
  # load topology from file and spawn processes
  stream = File.stream!("/home/marcos/rhul/tesis/files/" <> Integer.to_string(n) <> "nodes.txt")
  p_names = String.split(List.first(Enum.take(stream, 1)))
  p_ids = for name <- p_names do
    # alpha = spawn(Alpha,run, [Alpha.init_state()])
    pid = spawn(SyncMIS,:run, [SyncMIS.init_state(name,master_id)])
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
    send(id_origin,{:add_neighborhs, ids_destination}) end)
  end

defp process_by_name (name) do
  case :global.whereis_name(name) do
    :undefined -> :undefined
    pid -> pid
  end
end

def start_mis() do
  send(process_by_name(:master),{:start_mis})
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


      {:start_mis} ->
        Enum.each(state.processes, fn(pid) ->
          send(pid,{:find_mis,:initial})end)
        state

      {:complete,mis,active,sender,msg_count,round} -> # sender,round
        # IO.puts "In master recv complete from #{inspect sender}, active: #{active}
        # size: #{state.active_size}, count: #{state.count}"

        state = put_in(state, [:msg_count,:send], state.msg_count.send + msg_count)
        state = put_in(state, [:msg_count,:control], state.msg_count.control + 1)
        cond  do
          mis == true ->  ## node is part of MIS
            state = %{state | mis: state.mis ++ [sender]}
            IO.puts("ROUND #{round} process: #{inspect sender} add to MIS")
          active == false -> ## node is neighbor of node in MIS
            state = %{state | to_delete: state.to_delete ++ [sender]}
            IO.puts("ROUND #{round} process: #{inspect sender} NOT MIS")

        end


        if length(state.to_delete) + length(state.mis) == length(state.processes) do
          IO.puts("MIS complete: #{inspect state.mis}, MIS number nodes: #{length(state.mis)},
          Number rounds #{inspect state.round} , Number of messages + ack: #{state.msg_count.send * 2}
          , extra msg: #{state.msg_count.control}, network size: #{length(state.processes)}")
        end
        state


    end
    run_master(state)
  end
end
