defmodule Beta do

def init_state(name,master) do
%{
name: name,
parent: nil,
childs:[],
neighbors: [],
replies: 0,
root: false,
master_id: master,
}

end

def run(state) do
my_pid = self

  state = receive do

	{:add_neighbors, neighbors} ->
	  state = %{state | neighbors: neighbors}
	  state = %{state | replies: length(neighbors) - 1}

	{:start,:spanning_tree} ->
	  state = %{state | root: true}
	  Enum.each(state.neighbors, fn dest -> send dest,{:search,my_pid} end)
	  state

	{:search,origin} ->
	  if state.parent == nil do
		state = %{state | parent: origin}
		state = %{state | neighbors: state.neighbors}
		send origin,{:reply,:parent_of, my_pid}
	    Enum.each(state.neighbors  -- origin, fn dest -> send dest,{:search,my_pid} end)
	  else
		send origin, {:reply,:rejected, my_pid}
	  end
	  state

	{:reply, value, origin} ->
		if value == :parent_of do
			state = %{state | childs: state.childs ++ [origin]}
		end
		state = %{state | replies: state.replies - 1}
		if state.replies == 0, do: send master,{:complete_tree}
		state
  end
end

end
