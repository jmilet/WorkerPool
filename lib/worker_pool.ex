import QueueData

defmodule PoolState do
  defstruct max_processes: 0, current_processes: 0, error_handlers: %{}
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
    pid = spawn_monitor fn ->
      code.()
    end

    # Add the new process and increase the counter.
    error_handlers = Dict.put(state.error_handlers, pid, opts)
    current_processes = state.current_processes + 1
    {:reply, :ok,  %PoolState{state| error_handlers: error_handlers, current_processes: current_processes}}
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
    opts = Dict.get(state.error_handlers, key)

    # Runs the ok callback.
    if opts != nil do
      case reason do
        :normal -> if opts[:if_ok], do: opts[:if_ok].()
        error -> if opts[:if_error], do: opts[:if_error].(error)
      end
    end

    # Remove the process and decrease the counter.
    error_handlers = state.error_handlers |> Dict.delete(key)
    current_processes = state.current_processes - 1

    %PoolState{state| error_handlers: error_handlers, current_processes: current_processes}
  end
end
