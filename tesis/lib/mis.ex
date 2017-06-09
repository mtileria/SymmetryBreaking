defmodule MIS do

  def init_state(name, master) do
    %{ name: name,
       neighbors: [],
       n_size: 0,
       n_receive: 0,
       count: 0,
       master_id: master,
     }
  end

  def init_master(N) do
    %{
       processes: [],
       size: N,
       mis: [],
       round: 0,
       count: 0,
     }
  end

  def start_nodes (N) do
    master_id = spawn(mis,:master,init_master(N))
    case :global.register_name(:master,master_id) do
      :yes -> master_id
      :no -> :error
    end
    stream = File.stream!("/home/marcos/rhul/tesis/files/16nodes.txt")
    p_names = String.split(List.first(Enum.take(stream, 1)))
    pids = for name in p_names do
      spawn(mis,:run, [init_state(name,master_id)])
    end
    IO.puts("process ids: #{inspect pids}")
  end

  # def start(name,idp) do
  #   pid = spawn(mis,:run, [init_state(name,idp)])
  #   case :global.register_name(name,pid) do
  #     :yes -> pid
  #     :no  -> :error
  #   end
  # end

  def find_MIS(pid) do
    case :global.whereis_name(:master) do
      :undefined -> :undefined
      pid -> send(pid,{:start_mis})
    end
  end

  def create_edges() do
    case :global.whereis_name(:master) do
      :undefined -> :undefined
      pid -> send(pid,{:create_edges})
    end
  end

  def run(state) do

    my_pid = self()
    :random.seed(:erlang.now)
    value = :rand.uniform(100)

    state = receive do
      {:start_mis} ->
        for p <- state.neighbors do
          case :global.whereis_name(p) do
            :undefined -> :undefined
            pid -> send(pid,{:send_rand,my_pid,value})
          end



    end
        end



  run (state)
  end

  def master(state) do
    state =
      receive do
        {:create_edges} ->
          state

          {:start_mis} ->
            for p_id in state.processes do
              send(p_id,{:start_mis})
            end
            state

      end

  master(state)
  end

end
