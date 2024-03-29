require WorkerPool.Helper, as: H

defmodule WorkerPoolTest do
  use ExUnit.Case
  doctest WorkerPool

  ##########################################################################################################
  # Tests.
  ##########################################################################################################

  setup do
    :ok
  end

  test "The pool starts" do
    pool = H.make_pool_name()
    assert {:ok, _pid} = WorkerPool.start(pool)
    assert true == pool in Process.registered
    assert 0 == WorkerPool.current_processes(pool)
  end

  test "Runs a job which ends normally" do
    pool = H.make_pool_name()
    WorkerPool.start(pool)

    me = self

    WorkerPool.run pool, fn ->
      do_ok_job()
    end, on_error: fn ->
      send me, :error_job
    end, on_ok: fn ->
      send me, :ok_job
    end

    # Checks callback execution and counter.
    assert 1 == WorkerPool.current_processes(pool)
    assert_receive :ok_job, 2_000
    assert 0 == WorkerPool.current_processes(pool)
  end

  test "Runs a job which ends with error" do
    pool = H.make_pool_name()
    WorkerPool.start(pool)

    me = self

    WorkerPool.run pool, fn ->
      do_broken_job()
    end, on_error: fn(reason) ->
      send me, {:error_job, reason}
    end, on_ok: fn ->
      send me, :ok_job
    end

    # Checks callback execution and counter.
    assert 1 == WorkerPool.current_processes(pool)
    assert_receive {:error_job, _reason}, 2_000
    assert 0 == WorkerPool.current_processes(pool)
  end

  test "One job is ok the other on is error" do
    pool = H.make_pool_name()
    WorkerPool.start(pool)

    me = self

    WorkerPool.run pool, fn ->
      do_ok_job()
    end, on_error: fn(reason) ->
      send me, {:error_job_1, reason}
    end, on_ok: fn ->
      send me, :ok_job_1
    end

    WorkerPool.run pool, fn ->
      do_broken_job()
    end, on_error: fn(reason) ->
      send me, {:error_job_2, reason}
    end, on_ok: fn ->
      send me, :ok_job_2
    end

    # Checks callback execution and counter.
    assert 2 == WorkerPool.current_processes(pool)
    assert_receive :ok_job_1, 2_000
    assert_receive {:error_job_2, _reason}, 2_000
    assert 0 == WorkerPool.current_processes(pool)
  end

  test "Run out of processes" do
    pool = H.make_pool_name()
    WorkerPool.start(pool, 2)

    me = self()

    assert :ok == WorkerPool.run pool, fn -> do_ok_job() end, on_ok: fn -> send me, :ok1 end
    assert :ok == WorkerPool.run pool, fn -> do_ok_job() end, on_ok: fn -> send me, :ok2 end
    assert :error == WorkerPool.run pool, fn -> do_ok_job() end

    assert_receive :ok1, 2_000
    assert_receive :ok2, 2_000

    assert :ok == WorkerPool.run pool, fn -> do_ok_job() end, on_ok: fn -> send me, :ok3 end
    assert_receive :ok3, 2_000
  end

  test "Runs 1000 processes" do
    pool = H.make_pool_name()
    WorkerPool.start(pool, 2000)

    me = self()

    for i <- 1..1_000 do
      WorkerPool.run pool, fn -> do_ok_job(2_000) end, on_ok: fn -> send me, i end
    end

    assert 1_000 == WorkerPool.current_processes(pool)

    for i <- 1..1_000 do
      assert_receive ^i, 2_000
    end
  end

  test "Runs 2001 process and exceeds the pool size by one " do
    pool = H.make_pool_name()
    WorkerPool.start(pool, 2_000)

    me = self()

    ret = (for i <- 1..2_001, do: (WorkerPool.run pool, fn -> :timer.sleep 2_000; send me, i end))
    assert [:error] == ret |> Enum.filter &(&1 == :error)
    assert 2_000 == (ret |> Enum.filter &(&1 == :ok)) |> length

    ret = for _ <- 1..2_000 do
      receive do: (ret -> ret)
    end
    assert 2001000 == ret |> Enum.reduce(0, &(&1 + &2))

    assert :ok == WorkerPool.run pool, fn -> 1 end
  end

  test "The process timesout" do
    pool = H.make_pool_name()
    WorkerPool.start(pool, 10)

    me = self()

    WorkerPool.run pool, fn -> :timer.sleep(3_000) end, timeout: 100, on_timeout: fn -> send me, :job_timeout end
    assert_receive :job_timeout, 2_000
  end

  ##########################################################################################################
  # Private.
  ##########################################################################################################

  # OK job.
  defp do_ok_job(time \\ 200) do
    :timer.sleep time
  end

  # Broken job.
  defp do_broken_job(time \\ 200) do
    :timer.sleep time
    raise "caused error"
  end
end
