defmodule BetaMaster do


	def init_state(name, processes) do
		%{
		  name: name,
		  processes: processes,
		  replies: length(processes) - 1,
		  }
	end

	def spanning_tree (root) do
		case :global.whereis_name(:master) do
			undefined -> :error
			pid -> send pid, {:start,:mis}
		end
	end




	def run (state) do

	state =
	receive do

		{:spanning_tree, root} ->
			send root,{:start,:spanning_tree}
			state


		{:complete_tree} ->
	  		state = %{state | replies: state.replies - 1}
			if state.replies  == 0, do: IO.puts("Tree constructed")
			state

		{:start,:mis} ->
			Enum.each(state.processes, fn dest ->
				send dest,{:start,:mis}end)
			state

	end

end
