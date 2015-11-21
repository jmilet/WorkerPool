defmodule WorkerPoolTest do
  use ExUnit.Case
  doctest WorkerPool

  test "The pool starts" do
    pool = :pool1
    assert {:ok, _pid} = WorkerPool.start(pool)
    assert true == pool in Process.registered

    assert 0 == WorkerPool.current_processes(pool)
  end

  test "Runs a job which ends normally" do
    pool = :pool2
    WorkerPool.start(pool)

    me = self

    WorkerPool.run pool, fn ->
      :timer.sleep 200
      1
    end, if_error: fn ->
      send me, :error_job
    end, if_ok: fn ->
      send me, :ok_job
    end

    assert 1 == WorkerPool.current_processes(pool)
    assert_receive :ok_job, 2_000
    assert 0 == WorkerPool.current_processes(pool)
  end

  test "Runs a job which ends with error" do
    pool = :pool3
    WorkerPool.start(pool)

    me = self

    WorkerPool.run pool, fn ->
      :timer.sleep 200
      1 / 0
    end, if_error: fn(reason) ->
      send me, {:error_job, reason}
    end, if_ok: fn ->
      send me, :ok_job
    end

    assert 1 == WorkerPool.current_processes(pool)
    assert_receive {:error_job, _reason}, 2_000
    assert 0 == WorkerPool.current_processes(pool)
  end

  test "One job is ok the other on is error" do
    pool = :pool4
    WorkerPool.start(pool)

    me = self

    WorkerPool.run pool, fn ->
      :timer.sleep 200
      1
    end, if_error: fn(reason) ->
      send me, {:error_job_1, reason}
    end, if_ok: fn ->
      send me, :ok_job_1
    end

    WorkerPool.run pool, fn ->
      :timer.sleep 200
      1 / 0
    end, if_error: fn(reason) ->
      send me, {:error_job_2, reason}
    end, if_ok: fn ->
      send me, :ok_job_2
    end

    assert 2 == WorkerPool.current_processes(pool)
    assert_receive :ok_job_1, 2_000
    assert_receive {:error_job_2, _reason}, 2_000
    assert 0 == WorkerPool.current_processes(pool)
  end
end
