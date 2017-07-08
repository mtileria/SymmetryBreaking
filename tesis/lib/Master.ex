defmodule Master do


  def init_master(n) do
    %{
      processes: [],
      actives: [],
      to_delete: [],
      active_size: n,
      mis: [],
      round: 0,
      count: 0,
      count_topology: 0,
      msg_count: %{send: 0, control: 0},
    }
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
        state = %{state | actives: p_ids}
        state = %{state | active_size: length(p_ids)}

      {:start_mis} ->
        Enum.each(state.processes, fn(pid) ->
          send(pid,{:find_mis,:initial})end)
        state

      {:complete,mis,active,sender,msg_count} -> # sender,round
        state = %{state | count: state.count + 1}
        # IO.puts "In master recv complete from #{inspect sender}, active: #{active}
        # size: #{state.active_size}, count: #{state.count}"

        state = put_in(state, [:msg_count,:send], state.msg_count.send + msg_count)
        state = put_in(state, [:msg_count,:control], state.msg_count.control + 1)
        cond  do
          mis == true ->  ## node is part of MIS
            state = %{state | to_delete: state.to_delete ++ [sender]}
            state = %{state | mis: state.mis ++ [sender]}
          active == false -> ## node is neighbor of node in MIS
            state = %{state | to_delete: state.to_delete ++ [sender]}
          true ->
            state
        end

        if state.count == state.active_size do
            state = %{state | count: 0}
            state = %{state | round: state.round + 1}
            state = %{state | actives: state.actives -- state.to_delete}
            state = %{state | active_size: length(state.actives)}
            state = %{state | to_delete: []}
            IO.puts("ROUND #{state.round} FINISH!!!!!!!
            actives: #{inspect state.actives}, size:#{state.active_size} ")
            state
            case state.active_size == 0 do
              true ->
                IO.puts("MIS complete: #{inspect state.mis}, MIS number nodes: #{length(state.mis)}, Number rounds #{inspect state.round}
                  , Number of messages + ack: #{state.msg_count.send * 2} , extra msg: #{state.msg_count.control}
                   network size: #{length(state.processes)}")
                state
              false ->
                Enum.each(state.actives, fn(pid) ->
                  send(pid,{:update_topology})end)
                  state
            end
        end
        state

        {:update_complete,sender,size} ->
          state = %{state | count_topology: state.count_topology + 1}
          if state.count_topology == state.active_size do
            state = %{state | count_topology: 0}
            Enum.each(state.actives, fn(pid) ->
              send(pid,{:find_mis,:continue})end)
          end
          state

    end
    run_master(state)
  end
end
