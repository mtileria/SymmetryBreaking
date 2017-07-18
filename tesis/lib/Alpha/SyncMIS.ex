defmodule SyncMIS do
  @moduledoc """
    Implementation of Alpha Synchronizer
  """
  def init_state(name,master,alpha) do
    %{
      name: name,
      round: 0,
      master_id: master,
      synchronizer_id: alpha,
      destinations: %{}, # Map: #{destination -> synchronizer}
      count: 0,
      active: true,
      value: :rand.uniform(),
      mis: false,
      reply: 0,
      step: nil,
      count_phase: 0,
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

  # def enable_sync_recv(pid, round, messages,name) do
  #   IO.puts "Syncronuous receive in #{name}
  #    \n #{inspect messages} "
  # end

  def is_value_minimun(buffer,value) do
    Enum.all?(buffer,fn {_,y} ->
    value < y end)
  end

  def run(state) do
    my_pid = self()
    network_size = Enum.count(state.destinations)

    state = receive do

      {:set_value,y} ->
        state = %{state | value: y}

      {:add_neighborhs, map_pids} ->
        send(state.synchronizer_id,{:add_neighbors,Map.values(map_pids)})
        state = %{state | destinations: map_pids}

      {:kill} ->
        Process.exit(state.synchronizer_id,:kill)
        Process.exit(my_pid,:kill)

      {:find_mis,x,_} ->  # x = :continue || :initial
      state = %{state | step: :find_mis}
      state =
        if x == :continue, do: state = %{state | value: :rand.uniform()}, else: state
        sync_send(state.synchronizer_id,{:value,state.value})
        state



        {:sync_recv,:value,_,buffer} ->
          state = %{state | step: :recv_value}

          is_min = Enum.all?(buffer,fn {_,y} -> state.value < y end)
          # IO.puts "sync_recv in #{state.name}, my_value_min = #{is_min}"
          state =
          case is_min do
            true ->
              state = %{state | mis: true}
            false ->
              state
          end
          Enum.each(Map.keys(state.destinations), fn(x) -> send x,{:first_phase}end)
          state

        {:first_phase} ->
          state = %{state | count_phase: state.count_phase + 1}
          if state.count_phase == Enum.count(state.destinations) do
            state = %{state | count_phase: 0}
            sync_send(state.synchronizer_id,{:mis_status,state.mis})
            state
          else
            state
          end

        {:sync_recv,:mis_status,round,buffer} ->
          state = %{state | step: :recv_status}
          neighbor_mis = Enum.any?(buffer,fn {_,mis} -> mis == true end)
          if (state.mis == true || neighbor_mis == true)  do
            state = %{state | active: false}
            send(state.master_id,{:complete,:real,state.mis,state.active,
              my_pid,{2,3*network_size},round})
              ## NODE BECOME INACTIVE
              run_inactive(state)
              state
          else
            send(state.master_id,{:complete,:real,state.mis,state.active,
              my_pid,{2,2*3*network_size},round})
              state
          end
    end
    run (state)
  end

  def run_inactive(state) do
    my_pid = self
    network_size = Enum.count(state.destinations)

    state =
      receive do

        {:kill} ->
          Process.exit(state.synchronizer_id,:kill)
          Process.exit(my_pid,:kill)

        {:find_mis,:continue,_} ->
          state = %{state | step: :find_mis}
          sync_send(state.synchronizer_id,{:value,1})
          state

        {:sync_recv,:value,_,_} ->
            state = %{state | step: :recv_value}
            Enum.each(Map.keys(state.destinations), fn(x) -> send x,{:first_phase}end)
            state

        {:first_phase} ->
          state = %{state | count_phase: state.count_phase + 1}
          state =
          if state.count_phase == Enum.count(state.destinations) do
            state = %{state | count_phase: 0}
            sync_send(state.synchronizer_id,
              {:mis_status,false})
              state
          else
            state
          end

          {:sync_recv,:mis_status,round,_} ->
            state = %{state | step: :recv_status}
              send(state.master_id,{:complete,:dummy,state.mis,state.active,
                my_pid,{2,2*3*network_size},round})
              state

      end
   run_inactive(state)
   end
end
