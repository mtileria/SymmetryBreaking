defmodule Beta do
  @moduledoc """
    Implementation of Beta Synchronizer
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
    node: nil,
    parent: nil,
    childs: [],
}
end

  def start(name) do
    name = "Sync-" <> name
    pid = spawn(Beta,:run, [init_state(name)])
    case :global.register_name(name,pid) do
      :yes -> pid
      :no  -> :error
    end
  end


  def sync_send(origin,msg) do
    case :global.whereis_name(origin) do
      :undefined -> :undefined
      pid -> send(pid,{:sync_send,msg})
      #pid -> send(origin,{:sync_send,{state.destination,msg}})
    end
  end


  # def enable_sync_recv(pid, round, messages,name) do
  #   IO.puts "Syncronuous receive in #{name}
  #    \n #{inspect messages} "
  # end

  def run(state) do
    my_pid = self()
    state = receive do

      {:main_process,pid} ->
        state = %{state | node: pid}

      {:topology,parent,childs} ->
        state = %{state | parent: parent}
        state = %{state | childs: childs}

      {:add_neighbors,sync_pids} ->
         state = %{state | destinations: sync_pids}

      {:sync_send, messages} ->
        # IO.puts ("In #{inspect my_pid} sync_send #{inspect messages}")
        state = %{state | round: state.round + 1}
        {destinations,type,value} = messages
        state = %{state | destinations: destinations}
        state = %{state | ack_missing:
          Map.put(state.ack_missing, state.round, destinations)}
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
        if (length(Map.get(state.ack_missing, round)) == 0 && length(state.childs) == 0),
         do: send(state.parent,{:safe,round,my_pid}), else: state

      #change this part to reach the root of spanning tree
      {:safe, round, origin} ->
        state =
        if !(Map.has_key?(state.safe,round)) do
          state = %{ state | safe: Map.put(state.safe,round,[origin])}
        else
          state = update_in(state,[:safe,round], fn x -> x ++ [origin] end)
        end

        if (length(Map.get(state.safe, round)) == length(state.childs)) do
          case state.root do
            true ->
              Enum.each(state.childs, fn(x) -> send x,{:go,round} end)
            false ->
              send(state.parent,{:safe,round,my_pid})
          end
        end
        state


        {:go,round} ->
          {messages,tmp_buffer} = Map.pop(state.buffer,round)
          state = %{state | buffer: tmp_buffer }
          {type,_} = List.first(messages)
          send state.node,{:sync_recv, type, round, messages}
          state

    end
    run (state)
  end
end
