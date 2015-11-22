# WorkerPool

WorkerPool is a naive pool implementation. It's intended to
be just a prove of concept.

It's a minimal pool which limits the maximum number of processes
that can be executed concurrently. Optionally, it also limits the time a
given process has to complete.

When a new job on
a full pool is started, an `:error` atom is returned. In such a case, the starter process will have
to wait and try again.

Be aware that workers aren't pre-started. The pool just guarantees
some limits on system load.

In order to manage the different types of termination three optional
callbacks can be passed:

1. `on_ok` If present, called when the job correctly completes.
2. `on_error` If present, called when the job fails.
3. `on_time` If present, and `timeout` has been given, called when
the process hasn't finished on time.

The process associations are:

```
[caller] ---> [pool] ---monitor---> [job] <---link---> [timeout process]
```

This is a classic usage:

```Elixir
WorkerPool.start(:pool)

me = self

:ok = WorkerPool.run :pool, fn ->
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
