defmodule aSyncronizer do
  @moduledoc """
    Implementation of Alpha Synchronizer
  """
  def init_state(name,neighbors_list) do
    %{name: name,
	    neighbors: neighbors_list,
      expected_ack: length(neighbors_list),
      size: length(neighbors_list),
      count: 0,
      msg_count: 0,
  }

end

defp process_by_name (name) do
  case :global.whereis_name(name) do
    :undefined -> :undefined
    pid -> pid
  end
end

defp notify_neighbors(origin, destinations,msg) do
  {text,mis_status} = msg
  Enum.each(destinations,fn(dest) -> send(dest,{text,origin,mis_status})end)
end


  def run(state) do
    my_pid = self()
    state = receive do
    
    

    end
    run (state)
  end
end
