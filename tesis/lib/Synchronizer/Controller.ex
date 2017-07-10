defmodule Controller do


  def init_master(name) do
    %{
      name: name,
      processes: [],
      to_delete: [],
      size: 0,
      mis: [],
      count: 0,
      round: 0,
      not_mis: 0,
      active_size: 0,
      next_actives: [],
      count_replies: 0,
      msg_count: %{send: 0, control: 0},
      control: 0,
      control_value: 0,
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
    pid = SyncMIS.start(name,master_id)
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
    send(id_origin,{:add_neighborhs, map_destinations}) end)
  end

defp process_by_name (name) do
  case :global.whereis_name(name) do
    :undefined -> :undefined
    pid -> pid
  end
end

def set_values_test() do  ## for dummy example 0nodes file
  values = [0.4,0.3,0.1,0.5,0.2,0.6,0.7,0.8]
  case :global.whereis_name(:master) do
    :undefined -> :undefined
    pid -> send(pid,{:test_values, values})
  end
end

def start_mis() do
  send(process_by_name(:master),{:start_mis})
end


def run_master(state) do

    state =
    receive do

      {:test_values, values} ->  ## for dummy example "0nodes"
        tupleEnum = Enum.zip(state.processes, values)
        Enum.each(tupleEnum, fn {x,y} -> send(x,{:set_value,y})end)
        state

      {:add_processes_list,p_ids} ->
        state = %{state | processes: p_ids}
        state = %{state | size: length(p_ids)}
        state = %{state | active_size: length(p_ids)}

      {:start_mis} ->
        Enum.each(state.processes, fn(pid) ->
          send(pid,{:find_mis,:initial})end)
        state

      {:complete,mis,active,sender,msg_count,round} -> # sender,round
        # IO.puts "In master recv complete from #{inspect sender}, active: #{active}
        # size: #{state.active_size}, count: #{state.count}"
        state = %{state | count: state.count + 1}

        state = put_in(state, [:msg_count,:send], state.msg_count.send + msg_count)
        state = put_in(state, [:msg_count,:control], state.msg_count.control + 1)
        cond  do
          mis == true && active == false ->  ## node is part of MIS
            state = %{state | mis: state.mis ++ [sender]}
            state = %{state | to_delete: state.to_delete ++ [sender]}
          mis == false && active == false -> ## node is neighbor of node in MIS
            state = %{state | not_mis: state.not_mis + 1}
            state = %{state | to_delete: state.to_delete ++ [sender]}
          mis == false && active == true ->  ## node will continue in next round
            state
            # state = %{state | next_actives: state.next_actives ++ [sender]}
        end

        if state.count == state.active_size do
          state = %{state | count: 0}
          state = %{state | round: round}
          state = %{state | processes: state.processes -- state.to_delete}
          state = %{state | active_size: length(state.processes)}
          state = %{state | to_delete: []}
           IO.puts("ROUND #{state.round} FINISH!!!!!!!
            actives: #{inspect state.processes}, size:#{state.active_size} ")

          case state.active_size == 0 do
              true ->
                IO.puts("MIS complete: #{inspect state.mis}, MIS number nodes: #{length(state.mis)},
                Number rounds #{inspect state.round} , Number of messages + ack:
                 #{state.msg_count.send * 2} , extra msg: #{state.msg_count.control}
                   network size: #{length(state.processes)}")
                state
              false ->
                Enum.each(state.processes, fn(pid) ->
                  send(pid,{:update_topology})end)
                  state
          end
        end
        state

        {:update_complete,sender,size} ->
          state = %{state | count_replies: state.count_replies + 1}
          # IO.puts("update complete from #{inspect sender}, expected #{state.active_size}!")
          if (state.count_replies == state.active_size) do
             IO.puts("network update complete! start next round for
             #{length(state.processes)}!")
            state = %{state | count_replies: 0}
            Enum.each(state.processes, fn(pid) ->
              send(pid,{:find_mis,:continue})end)
          end
          state

          {:sync_recv_status} ->
            state = %{state | control: state.control + 1}
            IO.puts "R status: #{inspect state.control}"
            state

            {:sync_recv_value} ->
              state = %{state | control_value: state.control_value + 1}
              IO.puts "R value: #{inspect state.control_value}"
              state




        # IO.puts("Finish in ROUND #{round} process: #{inspect sender} add to MIS, #{state.count}")
        # IO.puts("Finish in ROUND #{round} process: #{inspect sender} NOT MIS, #{state.count}")




        state


    end
    run_master(state)
  end
end
