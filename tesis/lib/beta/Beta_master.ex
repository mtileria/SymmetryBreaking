# defmodule BetaMaster do
#
#
# 	def init_state(name) do
# 		%{
# 		  name: name,
# 		  processes: [],
# 		  count: 0,
# 		  replies: 0,
# 		  }
# 	end
#
# 	def spanning_tree (name) do
# 		case :global.whereis_name(name) do
# 			undefined -> :error
# 			pid -> send pid, {:spanning_tree,:start}
# 		end
# 	end
#
# 	def start_mis() do
# 		case :global.whereis_name(:master) do
# 			undefined -> :error
# 			pid -> send pid, {:search_mis,:start}
# 		end
# 	end
#
#
#
#
# 	def run (state) do
#
# 	state =
# 	receive do
#
# 		{:complete_tree} ->
# 	  		state = %{state | replies: state.replies - 1}
# 			if state.replies  == 0, do: IO.puts("Tree constructed")
# 			state
#
# 		{:search,:mis} ->
# 			Enum.each(state.processes, fn dest ->
# 				send dest,{:search,:start}end)
# 			state
#
# 	end
# run(state)
# end
# end
