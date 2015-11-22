import QueueData

defmodule PoolState do
  defstruct max_processes: 0, current_processes: 0, handlers: %{}
end

defmodule WorkerPool do
  use GenServer

  @default_max_processes 10

  ##########################################################################################################
  # API.
  ##########################################################################################################

  def start(name, max_processes \\ @default_max_processes) do
    GenServer.start(__MODULE__, max_processes, name: name)
  end

  @doc """
  `max_processes` The max. number of processes of the pool.
  """
  def init(max_processes) do
    {:ok, %PoolState{max_processes: max_processes}}
  end

  @doc """
  Run a process.
  """
  def run(pool, code, opts \\ []) do
    GenServer.call(pool, {:run, code, opts})
  end

  @doc """
  Returns the number of current processes.
  """
  def current_processes(pool) do
    GenServer.call(pool, :current_processes)
  end

  ##########################################################################################################
  # Callbacks.
  ##########################################################################################################

  def handle_call(:current_processes, _from, state) do
    {:reply, state.current_processes, state}
  end

  def handle_call({:run, code, opts}, _from, state) do
    if state.current_processes == state.max_processes do
      {:reply, :error, state}
    else

      # Spawns the monitored process.
      pid = spawn_monitor fn ->
        monitored = self()

        # If timeout is given we link a timer to the monitored process.
        if opts[:timeout] do
          spawn_link fn ->
            :timer.sleep opts[:timeout]
            Process.exit(monitored, :timeout)
          end
        end

        # Run the actual code.
        code.()
      end

      # Add the new process and increase the counter.
      handlers = Dict.put(state.handlers, pid, opts)
      current_processes = state.current_processes + 1
      {:reply, :ok,  %PoolState{state| handlers: handlers, current_processes: current_processes}}
    end
  end

  # Handle correct termination.
  def handle_info({:DOWN, ref, :process, pid, :normal}, state) do
    {:noreply, handle_down(pid, ref, :normal, state)}
  end

  # Handle error termination.
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    {:noreply, handle_down(pid, ref, reason, state)}
  end

  # Common termination logic.
  defp handle_down(pid, ref, reason, state) do
    # Looks the process up.
    key = {pid, ref}
    opts = Dict.get(state.handlers, key)

    # Runs the ok callback.
    if opts != nil do
      case reason do
        :normal -> if opts[:on_ok], do: opts[:on_ok].()
        :timeout -> if opts[:on_timeout], do: opts[:on_timeout].()
        error -> if opts[:on_error], do: opts[:on_error].(error)
      end
    end

    # Remove the process and decrease the counter.
    handlers = state.handlers |> Dict.delete(key)
    current_processes = state.current_processes - 1

    %PoolState{state| handlers: handlers, current_processes: current_processes}
  end
end
