defmodule WorkerPool.Helper do
  ##########################################################################################################
  # Macros.
  ##########################################################################################################

  # Returns position in the file.
  defmacro where_am_i do
    quote do
      "#{__ENV__.file}_#{__ENV__.line}"
    end
  end

  # Generates a pool name.
  defmacro make_pool_name do
    quote do
      "pool_#{WorkerPool.Helper.where_am_i}" |> String.to_atom
    end
  end

  defmacro spit(text) do
    quote do
      IO.ANSI.format([:red, "#{where_am_i |> Path.basename} -> '", unquote(text), "'"]) |> IO.puts
    end
  end
end
