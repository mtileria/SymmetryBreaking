defmodule Controller do


  def init_master(name) do
    %{
      name: name,
      processes: [],
      size: 0,
      mis: [],
      count: 0,
      round: 0,
      not_mis: 0,
      count_replies: 0,
      new_mis: 0,
      actives: 0,
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

      {:start_mis} ->
        Enum.each(state.processes, fn(pid) ->
          send(pid,{:find_mis,:initial})end)
        state

        {:alive} ->
          safe = Enum.all?(state.processes, fn x -> Process.alive?(x) end )
          IO.puts "All alive = #{safe}"
          state

        {:processes,sender} ->
          send sender,{:list,state.processes}
          state

        {:controlador,first_status} ->
          Enum.each(state.processes, fn(x) -> send x,{:status,self,first_status} end)
          state

        {:reply,sender,status} ->
          IO.puts("origin #{inspect sender} status: #{status}")
          state



      {:complete,type,mis,active,sender,msg_count,round} -> # sender,round
        #  IO.puts "In master recv complete from #{inspect sender}, active: #{active}
        #   count: #{state.count}"
        state = %{state | count: state.count + 1}
        # IO.puts("tt: #{state.count} " )
        state = put_in(state, [:msg_count,:send], state.msg_count.send + msg_count)
        state = put_in(state, [:msg_count,:control], state.msg_count.control + 1)
        cond  do
          type == :dummy ->
            state
          active == false && mis == true->  ## node is part of MIS
            state = %{state | mis: state.mis ++ [sender]}
            state = %{state | new_mis: state.new_mis + 1}
          active  == false && mis == false -> ## node is neighbor of node in MIS
            state = %{state | not_mis: state.not_mis + 1}
          active == true && mis == false ->  ## node will continue in next round
            state = %{state | actives: state.actives + 1}
        end

        if state.count == length(state.processes) do
          IO.puts("ROUND #{state.round + 1} FINISH!!! New In MIS #{state.new_mis}, actives: #{state.actives} ")
          state = %{state | count: 0}
          state = %{state | round: state.round + 1}
          state = %{state | new_mis: 0}
          state = %{state | actives: 0}

          case length(state.mis) + state.not_mis == length(state.processes) do
              true ->
                IO.puts("\n\n ****MIS complete*****: #{inspect state.mis}, MIS number nodes: #{length(state.mis)},
                Number rounds #{inspect state.round} , Number of messages + ack:
                 #{state.msg_count.send * 2} , extra msg: #{state.msg_count.control}
                   network size: #{length(state.processes)}")
                state
              false ->
                Enum.each(state.processes, fn(pid) ->
                  send(pid,{:find_mis,:continue})end)
                  state
          end
        end
        state

    end
    run_master(state)
  end
end
