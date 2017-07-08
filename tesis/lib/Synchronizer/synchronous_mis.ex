defmodule SyncMIS do
  @moduledoc """
    Implementation of Alpha Synchronizer
  """
  def init_state(name,master) do
    %{name: name,
	    buffer: %{},
      ack_missing: %{},
      destinations: [],
      safe: %{},
      round: 0,
      msg_count: 0,

      ###### this section is for MIS algorithm
      master_id: master,
      synchronizer_id:
      count: 0,
      active: true,
      to_delete: [],
      value: :rand.uniform(),
      mis: false,
      reply: 0,
  }

end

  def start(name,master) do
    pid = spawn(SyncMIS,:run, [init_state(name,master)])
    case :global.register_name(name,pid) do
      :yes -> pid
      :no  -> :error
    end
  end


  def sync_send(origin,msg) do
      send(origin,{:sync_send,msg})
    end

  def enable_sync_recv(pid, round, messages,name) do
    IO.puts "Syncronuous receive in #{name}
     \n #{inspect messages} "
  end

  def is_value_minimun(buffer,round,value) do
    Enum.all?(Map.get(buffer,round),fn {x,y} ->
    value < y end)
  end

  defp notify_neighbors(destinations,msg,value,my_pid) do
    case msg do
      :mis_member ->
        Enum.each(destinations,fn(dest) -> send(dest,{:mis_member,value,my_pid})end)
      :update_network ->
        Enum.each(destinations,fn(dest) -> send(dest,{:update_network,my_pid})end)
      end
  end

  def run(state) do
    my_pid = self()
    neighbors_size = length(state.destinations)

    state = receive do

      {:add_neighborhs, pids} ->
        state = %{state | destinations: pids  -- [my_pid]}

      {:sync_send, messages} ->
        IO.puts ("In #{inspect my_pid} sync_send #{inspect messages}")
        {destinations,msg} = messages
        state = %{state | round: state.round + 1}
        #state = %{state | destinations: distinations}
        state = %{state | ack_missing:
          Map.put(state.ack_missing, state.round, destinations ++ destinations)}
        Enum.each(destinations, fn(dest) ->
          send(dest,{:async_msg,state.round,msg,my_pid})end)
        state

      {:async_msg,round,msg,origin} ->
      #  IO.puts ("In #{inspect my_pid} async_msg, round #{round}")
        if !(Map.has_key?(state.buffer,round)) do
          state = %{ state | buffer: Map.put(state.buffer,round,[{origin,msg}])}
        else
          state = update_in(state,[:buffer,round], fn x -> x ++ [{msg,origin}]end)
        end
        send(origin,{:async_ack,my_pid,round})

        ## MIS section
        if (length(Map.get(state.buffer, round)) == neighbors_size) do
          min =  is_value_minimun(state.buffer,round,msg)
          case min do
            true ->
              state = %{state | mis: true}
              state = %{state | active: false}
            false ->
              state
          end
          notify_neighbors(state.destinations,:mis_member,state.mis,my_pid)
        end
        state


      {:async_ack,origin, round} ->
        state = update_in(state,[:ack_missing,round], fn x -> x -- [origin] end)
        if (length(Map.get(state.ack_missing, round)) == 0) do
          Enum.each(state.destinations, fn(dest) ->
            send(dest,{:safe,state.round,my_pid})end)
        end
        state

      {:mis_member, value, origin} ->
        if value == true do
          IO.puts "mis_member recv in #{state.name} from #{inspect origin}"
          state = %{state | active: false}
        end
        send(origin,{:async_ack,my_pid,state.round})
        state


        {:safe, round, origin} ->
          IO.puts ("In #{state.name} safe from #{inspect origin} round #{round}")
          if !(Map.has_key?(state.safe,round)) do
            state = %{ state | safe: Map.put(state.safe,round,[origin])}
          else
            state = update_in(state,[:safe,round], fn x -> x ++ [origin] end)
          end

          if (length(Map.get(state.safe, round)) == neighbors_size) do
          #  IO.puts "Ready to safaly receive in #{inspect my_pid}"
          #  enable_sync_recv(my_pid,round, Map.get(state.buffer,round),state.name)
            if state.active == true do
              notify_neighbors(state.destinations,:update_network,0,my_pid)
            else
              send(state.master_id,{:complete,state.mis,state.active,
                my_pid,neighbors_size,state.round})
            end
          end
          state

          ## from here is MIS algorithm

          {:find_mis,x} ->  # x = :continue || :initial
            IO.puts "find_mis in #{state.name}"

            if x == :continue do
                state = %{state | value: :rand.uniform()}
            end

            case length(state.destinations) > 0 do
              true ->
                sync_send(my_pid,{state.destinations,state.value})
                state
              false ->
                state = %{state | active: false}
                state = %{state | mis: true}
                send(state.master_id,{:complete,state.mis,state.active,my_pid,0,state.round})
                state
            end
            state



          {:update_network,origin} ->
            send(origin,{:reply_update_network,state.active,my_pid})
            state

          {:reply_update_network, active,origin} ->
            IO.puts "reply_update_network in #{inspect state.name} from #{inspect origin}"
            state = %{state | reply: state.reply + 1}
            cond do
              active == false ->
                state = %{state | to_delete: state.to_delete ++ [origin]}
              active == true ->
                state
            end

            if state.reply == neighbors_size do
              # IO.puts "recv all update_reply in #{inspect my_pid}, size neigh: #{state.n_size}"
                state = %{state | destinations: state.destinations -- state.to_delete}
                state = %{state | to_delete: []}
                state = %{state | reply: 0}
                ## CONTINUE NEXT ROUND
                send(my_pid,{:find_mis,:continue})
                state
            end
            state
    end
    run (state)
  end
end
