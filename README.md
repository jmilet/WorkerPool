# WorkerPool

WorkerPool is a naive pool implementation. It's intended to
be just a prove of concept.

It's a simple pool which executes the code is given in the `run`
function provided the maximum number of processes isn't reached. In such a case, an `:error` would be returned.

Be aware that workers aren't pre-started. The
pool just guarantees that the maximum load is under control.

Important optionals params:

1. The `start` function can specify the max number of processes.
2. Callbacks `on_ok`, `on_error` and `on_timeout` can be given in order to be called whenever these events occur.


This is a classic usage:

```Elixir
WorkerPool.start(:pool)

me = self

WorkerPool.run :pool, fn ->
  do_job()
end, on_ok: fn ->
  send me, :ok_job
end, on_error: fn(reason) ->
  send me, {:error_job, reason}
end, on_timeout: fn ->
  send me, :timeout_job
end
```


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add worker_pool to your list of dependencies in `mix.exs`:

        def deps do
          [{:worker_pool, "~> 0.0.1"}]
        end

  2. Ensure worker_pool is started before your application:

        def application do
          [applications: [:worker_pool]]
        end
