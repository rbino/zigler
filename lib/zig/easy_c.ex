defmodule Zig.EasyC do
  require EEx

  easy_c = Path.join(__DIR__, "templates/easy_c.zig.eex")
  EEx.function_from_file(:def, :build_from, easy_c, [:assigns])

  def normalize_aliasing(opts) do
    if opts[:easy_c] do
      Keyword.update!(opts, :nifs, &add_aliasing/1)
    else
      opts
    end
  end

  defp add_aliasing(:all) do
    raise "can't have all on an easy_c module"
  end

  defp add_aliasing(list) do
    Enum.map(list, fn {fun, opts} -> {fun, Keyword.put(opts, :alias, true)} end)
  end
end
