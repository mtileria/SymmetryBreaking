defmodule MyAlpha do
  @moduledoc """
    Implementation of Alpha Synchronizer
  """

def init_state(name) do
  %{name: name,
    buffer: %{},
    ack_missing: %{},
    destinations: %{},
    safe: %{},
    count: 0,
    round: 0,
    msg_count: 0,
    node: nil,
}
end

  def start(name) do
    name = "Sync-" <> name
    pid = spawn(MyAlpha,:run, [init_state(name)])
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

      {:main_process,pid} ->
        state = %{state | node: pid}

      {:sync_send, messages} ->
        # IO.puts ("In #{inspect my_pid} sync_send #{inspect messages}")
        state = %{state | round: state.round + 1}
        {destinations,type,value} = messages
        state = %{state | destinations: Map.put(state.destinations,state.round,destinations)}
        state = %{state | ack_missing:
         Map.put(state.ack_missing, state.round, destinations)}
        if (Map.has_key?(state.safe, state.round)) do
          send(my_pid,{:control,state.round})
        end
        Enum.each(destinations, fn(dest) ->
          send(dest,{:async_msg,state.round,type,value,my_pid})end)
        state

      {:async_msg,round,type,value,origin} ->
        if !(Map.has_key?(state.buffer,round)) do
          state = %{ state | buffer: Map.put(state.buffer,round,[{type,value}])}
        else
          state = update_in(state,[:buffer,round], fn x -> x ++ [{type,value}]end)
        end
        send(origin,{:async_ack,my_pid,round})
        state

      {:async_ack, origin, round} ->
        state = update_in(state,[:ack_missing,round], fn x -> x -- [origin] end)
        if (length(Map.get(state.ack_missing, round)) == 0) do
          Enum.each(Map.get(state.destinations,round), fn(dest) ->
            send(dest,{:safe,round,my_pid})end)
        end
        state

      {:safe, round, origin} ->
        if !(Map.has_key?(state.safe,round)) do
          state = %{ state | safe: Map.put(state.safe,round,[origin])}
        else
          state = update_in(state,[:safe,round], fn x -> x ++ [origin] end)
        end
        if (Map.has_key?(state.destinations, round)) do
          send(my_pid,{:control,round})
        end
        state

        {:control,round} ->
          if (length(Map.get(state.safe, round)) == length(Map.get(state.destinations,round))) do
            {messages,tmp_buffer} = Map.pop(state.buffer,round)
            state = %{state | buffer: tmp_buffer }
            {type,_} = List.first(messages)
            send state.node,{:sync_recv, type, round, messages}
          end

        # {:new_topology,active_nodes} ->
        #   state = %{ state | destinations: active_nodes}
        #   send(state.node,{:topology_ok})
        #   state

    end
    run (state)
  end
end
