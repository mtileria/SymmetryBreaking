# defmodule MisBeta do
#
# def init_state(name,master,beta) do
# %{
# name: name,
# parent: nil,
# childs: [],
# neighbors: %{},
# replies: 0,
# root: false,
# master_id: master,
# synchronizer_id: beta,
# }
#
# end
#
# def pre_run(state) do
# my_pid = self
#
#   state = receive do
#
# 	{:add_neighbors, neighbors} ->
# 	  state = %{state | neighbors: neighbors}
# 	  state = %{state | replies: Enum.count(neighbors) - 1}
#
# 	{:start,:spanning_tree} ->
# 	  state = %{state | root: true}
# 	  state = %{state | replies: Enum.count(neighbors)}
# 	  Enum.each(Map.keys(state.neighbors), fn dest -> send dest,{:search,my_pid} end)
# 	  state
#
# 	{:search,origin} ->
# 	  if state.parent == nil do
# 		state = %{state | parent: {origin,Map.get(state.neighbors,origin)}}
# 		send origin,{:reply,:parent_of, my_pid}
# 	        Enum.each(Map.keys(state.neighbors)  -- [origin], fn dest -> send dest,{:search,my_pid} end)
# 	  else
# 		send origin, {:reply,:rejected, my_pid}
# 	  end
# 	  state
#
# 	{:reply, value, origin} ->
# 	  if value == :parent_of do
# 	    state = %{state | childs: Map.put(state.childs,origin,Map.get(state.neighbors,origin))}
# 	  end
# 	  state = %{state | replies: state.replies - 1}
# 	  if state.replies == 0 do
# 	    send state.synchronizer_id,{:topology,state.parent,state.childs}
# 	    send master_id,{:complete_tree}
# 	    run(state)
# 	  end
# 	  state
#     end
# end
#
# def run(state) do
#
#
#
# end
#
#
#
#
# end
