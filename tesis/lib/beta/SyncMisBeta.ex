defmodule SyncMisBeta do

  def init_state(name,master,beta) do
  %{
    name: name,
    parent: nil,
    childs: %{},
    neighbors: %{},
    st_replies: 0,
    root: false,
    master_id: master,
    synchronizer_id: beta,
    }
  end

  def start(name,master) do
    beta = Beta.start(name)
    pid = spawn(SyncMisBeta,:pre_run, [init_state(name,master,beta)])
    send(beta,{:main_process,pid})
    case :global.register_name(name,pid) do
      :yes -> pid
      :no  -> :error
    end
  end

  def sync_send(synchronizer,msg) do
    send(synchronizer,{:sync_send,msg})
  end

  def pre_run(state) do
  my_pid = self

    state = receive do

  	{:add_neighbors, neighbors} ->
  	  state = %{state | neighbors: neighbors}
  	  state = %{state | st_replies: Enum.count(neighbors) - 1}

  	{:spanning_tree,:root} ->
      state = %{state | root: true}
  	  state = %{state | st_replies: Enum.count(state.neighbors)}
  	  Enum.each(Map.keys(state.neighbors), fn(dest) -> send dest,{:search,:rst,my_pid} end)
  	  state

  	{:search,:rst,origin} ->
  	  if state.parent == nil do
  		  state = %{state | parent: {origin,Map.get(state.neighbors,origin)}}
  		  send origin,{:reply,:parent_of, my_pid}
  	    Enum.each(Map.keys(state.neighbors)  -- [origin],
          fn dest -> send dest,{:search,:rst,my_pid} end)
        state
  	  else
  		  send origin, {:reply,:rejected, my_pid}
        state
  	  end


  	{:reply, value, origin} ->
      state =
      if value == :parent_of, do:  state = %{state | childs:
        Map.put(state.childs,origin,Map.get(state.neighbors,origin))}, else: state
  	  state = %{state | st_replies: state.st_replies - 1}
  	  if state.st_replies == 0 do
  	    send state.synchronizer_id,{:topology,state.parent,Map.values(state.childs)}
  	    send state.master_id,{:completed_node}
  	    run(state)
  	  else
  	     state
      end

    end
    pre_run(state)
  end

  def run(state) do

    my_pid = self()
    network_size = Enum.count(state.neighbors)
    state = receive do

      {:kill} ->
        Process.exit(state.synchronizer_id,:kill)
        Process.exit(my_pid,:kill)

      {:find_mis,x} ->  # x = :continue || :initial
        state = %{state | step: :find_mis}
        state =
          if x == :continue, do: state =
            %{state | value: :rand.uniform()}, else: state
        sync_send(state.synchronizer_id,{:value,state.value})
        state



      {:sync_recv,:value,_,buffer} ->
        state = %{state | step: :recv_value}
        is_min = Enum.all?(buffer,fn {_,y} -> state.value < y end)
        state =
        case is_min do
          true ->
            state = %{state | mis: true}
          false ->
            state
        end
        Enum.each(Map.keys(state.neighbors), fn(x) -> send x,{:first_phase}end)
        state

      {:first_phase} ->
        state = %{state | count_phase: state.count_phase + 1}
        if state.count_phase == Enum.count(state.neighbors) do
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
            my_pid,{2,4*network_size},round})
            ## NODE BECOME INACTIVE
            run_inactive(state)
            state
        else
          send(state.master_id,{:complete,:real,state.mis,state.active,
            my_pid,{2,4*network_size},round})
            state
        end
    end
    run (state)
  end

  def run_inactive(state) do
    my_pid = self
    network_size = Enum.count(state.neighbors)

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
            Enum.each(Map.keys(state.neighbors), fn(x) -> send x,{:first_phase}end)
            state

        {:first_phase} ->
          state = %{state | count_phase: state.count_phase + 1}
          state =
          if state.count_phase == Enum.count(state.neighbors) do
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
                my_pid,{2,4*network_size},round})
              state

      end
   run_inactive(state)
   end

end