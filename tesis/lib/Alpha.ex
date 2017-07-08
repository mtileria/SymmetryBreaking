defmodule ASyncronizer do
  @moduledoc """
    Implementation of Alpha Synchronizer
  """
  def init_state(name) do
    %{name: name,
	    buffer: %{},
      ack_missing: %{},
      destinations: [],
      safe: %{},
      count: 0,
      round: 0,
      msg_count: 0,
  }
end

  def start(name) do
    pid = spawn(ASyncronizer,:run, [init_state(name)])
    case :global.register_name(name,pid) do
      :yes -> pid
      :no  -> :error
    end
  end

  def create_processes(participants) do
    pids = for name <- participants do
      start(name)
    end
    Enum.each(pids, (fn (pid) -> send(pid,{:destinations, pids})end))
  end

  def sync_send(origin,msg) do
    case :global.whereis_name(origin) do
      :undefined -> :undefined
      pid -> send(pid,{:sync_send,msg})
      #pid -> send(origin,{:sync_send,{state.destination,msg}})
    end
  end

  def enable_sync_recv(pid, round, messages,name) do
    IO.puts "Syncronuous receive in #{name}
     \n #{inspect messages} "
  end

  def run(state) do
    my_pid = self()
    state = receive do

      {:destinations, pids} ->
        state = %{state | destinations: pids  -- [my_pid]}

      {:sync_send, messages} ->
      #  IO.puts ("In #{inspect my_pid} sync_send #{messages}")
        msg = messages
        #{destinations,msg} = messages
        state = %{state | round: state.round + 1}
        #state = %{state | destinations: distinations}
        state = %{state | ack_missing: Map.put(state.ack_missing, state.round, state.destinations) }
        Enum.each(state.destinations, fn(dest) ->
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
        state

      {:async_ack, origin, round} ->
      #  IO.puts ("In #{inspect my_pid} async_ack recv in round#{round} from #{inspect origin}")
        state = update_in(state,[:ack_missing,round], fn x -> x -- [origin] end)
        if (length(Map.get(state.ack_missing, round)) == 0) do
          Enum.each(state.destinations, fn(dest) ->
            send(dest,{:safe,state.round,my_pid})end)
        end
        state

        {:safe, round, origin} ->
          #IO.puts ("In #{state.name} safe from #{inspect origin} round #{round}")
          if !(Map.has_key?(state.safe,round)) do
            state = %{ state | safe: Map.put(state.safe,round,[origin])}
          else
            state = update_in(state,[:safe,round], fn x -> x ++ [origin] end)
          end

          if (length(Map.get(state.safe, round)) == length(state.destinations)) do
          #  IO.puts "Ready to safaly receive in #{inspect my_pid}"
            enable_sync_recv(my_pid,round, Map.get(state.buffer,round),state.name)
          end
          state


    end
    run (state)
  end
end
