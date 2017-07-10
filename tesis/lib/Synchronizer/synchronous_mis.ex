defmodule SyncMIS do
  @moduledoc """
    Implementation of Alpha Synchronizer
  """
  def init_state(name,master,alpha) do
    %{
      name: name,
      round: 0,
      msg_count: 0,
      master_id: master,
      synchronizer_id: alpha,
      destinations: %{}, # Map: #{destination -> synchronizer}
      count: 0,
      active: true,
      to_delete: [],
      value: :rand.uniform(),
      mis: false,
      reply: 0,
  }

end

  def start(name,master) do
    alpha = Alpha.start(name) #spawn(Alpha,:run, [Alpha.init_state(name)])
    pid = spawn(SyncMIS,:run, [init_state(name,master,alpha)])
    send(alpha,{:main_process,pid})
    case :global.register_name(name,pid) do
      :yes -> pid
      :no  -> :error
    end
  end


  def sync_send(synchronizer,msg) do
      send(synchronizer,{:sync_send,msg})
    end

  def enable_sync_recv(pid, round, messages,name) do
    IO.puts "Syncronuous receive in #{name}
     \n #{inspect messages} "
  end

  def is_value_minimun(buffer,value) do
    Enum.all?(buffer,fn {x,y} ->
    value < y end)
  end

  def run(state) do
    my_pid = self()
    neighbors_size = Enum.count(state.destinations)

    state = receive do

      {:set_value,y} ->
        state = %{state | value: y}

      {:add_neighborhs, map_pids} ->
        send(state.synchronizer_id,{:add_neighbors,Map.values(map_pids)})
        state = %{state | destinations: map_pids}


      {:find_mis,x} ->  # x = :continue || :initial

        if x == :continue do
          state = %{state | value: :rand.uniform()}
        end

        case Enum.count(state.destinations) > 0 do
          true ->
            sync_send(state.synchronizer_id,
              {Map.values(state.destinations),:value,state.value})
            state
          false ->
            state = %{state | active: false}
            state = %{state | mis: true}
            send(state.master_id,{:complete,state.mis,state.active,my_pid,0,state.round})
            state
        end
        state

        {:sync_recv,:value,round,buffer} ->
          if round >= 2 do
            send(state.master_id,{:sync_recv_value})
          end
          is_min = Enum.all?(buffer,fn {x,y} -> state.value < y end)
          # IO.puts "sync_recv in #{state.name}, my_value_min = #{is_min}"
          case is_min do
            true ->
              state = %{state | mis: true}
            false ->
              state
          end
          sync_send(state.synchronizer_id,
            {Map.values(state.destinations),:mis_status,state.mis})
          state

        {:sync_recv,:mis_status,round,buffer} ->
          if round >= 3 do
            send(state.master_id,{:sync_recv_status})
          end
          neighbor_mis = Enum.any?(buffer,fn {x,mis} -> mis == true end)
          if (neighbor_mis == true || state.mis == true)  do
            state = %{state | active: false}
          end
          send(state.master_id,{:complete,state.mis,state.active,
            my_pid,neighbors_size,state.round})
          state

      {:update_topology} ->
        Enum.each(Map.keys(state.destinations),
          fn(dest) -> send(dest,{:update_network,my_pid})end)
        state

      {:update_network,origin} ->
        send(origin,{:reply_update_topology,state.active,my_pid})
        state

      {:reply_update_topology, active,origin} ->
        # IO.puts "reply_update_network in #{inspect state.name} from #{inspect origin}"
        state = %{state | reply: state.reply + 1}
        cond do
          active == false ->
            state = %{state | to_delete: state.to_delete ++ [origin]}
          active == true ->
            state
        end
        if state.reply == neighbors_size do
            # IO.puts "recv all update_reply in #{inspect my_pid}"
            state = %{state | destinations: Map.drop(state.destinations,state.to_delete)}
            state = %{state | to_delete: []}
            state = %{state | reply: 0}
            send(state.synchronizer_id,{:new_topology,Map.values(state.destinations)})
        #    send(state.master_id,{:update_complete,my_pid,neighbors_size})
            state
        end
        state

        {:topology_ok} ->
          send(state.master_id,{:update_complete,my_pid,neighbors_size})
          state

    end
    run (state)
  end
end
