defmodule Zig.Nif.Basic do
  @moduledoc """
  Architecture:

  Synchronous has two different cases.  The first case is that the nif can be called
  directly.  In this case, the function is mapped directly to function name.  In the
  case that the nif needs marshalling, the function is mapped to `marshalled-<nifname>`.
  and the called function contains wrapping logic.

  To understand wrapping logic, see `Zig.Nif.Marshaller`
  """

  alias Zig.ErrorProng
  alias Zig.Nif
  alias Zig.Type
  alias Zig.Type.Function

  import Zig.QuoteErl

  # marshalling setup

  defp needs_marshal?(nif) do
    Enum.any?(nif.type.params, &Type.marshals_param?/1)
    or Type.marshals_return?(nif.type.return)
    or error_prongs(nif) !== []
  end

  defp error_prongs(nif) do
    nif.type.params
    |> Enum.map(&Type.error_prongs(&1, :argument))
    |> List.insert_at(0, Type.error_prongs(nif.type.return, :return))
    |> List.flatten
  end

  defp marshal_name(nif), do: :"marshalled-#{nif.type.name}"

  def entrypoint(nif) do
    if needs_marshal?(nif), do: marshal_name(nif), else: nif.type.name
  end

  def render_elixir(nif = %{type: type}) do
    params =
      case type.arity do
        0 -> []
        n -> Enum.map(1..n, &{:"_arg#{&1}", [], Elixir})
      end

    error_text = "nif for function #{type.name}/#{type.arity} not bound"

    def_or_defp = if nif.export, do: :def, else: :defp

    if needs_marshal?(nif) do
      marshal_name = marshal_name(nif)
      error_prongs = nif
      |> error_prongs()
      |> Enum.flat_map(&apply(ErrorProng, &1, [:elixir]))

      quote do
        unquote(def_or_defp)(unquote(type.name)(unquote_splicing(params))) do
          unquote(marshal_name)(unquote_splicing(params))
        catch
          unquote(error_prongs)
        end

        defp unquote(marshal_name)(unquote_splicing(params)) do
          :erlang.nif_error(unquote(error_text))
        end
      end
    else
      quote context: Elixir do
        unquote(def_or_defp)(unquote(type.name)(unquote_splicing(params))) do
          :erlang.nif_error(unquote(error_text))
        end
      end
    end
  end

  def render_erlang(nif = %{type: type}) do
    vars =
      case type.arity do
        0 -> []
        n -> Enum.map(1..n, &{:var, :"_X#{&1}"})
      end

    error_text = ~c'nif for function #{nif.entrypoint}/#{type.arity} not bound'

    if needs_marshal?(nif) do
      error_prongs = []

      quote_erl(
        """
        unquote(function_name)(unquote(...vars)) ->
          try unquote(marshal_name)(unquote(...vars)) of
          catch
            unquote(...error_prongs)
          end.

        unquote(marshal_name)(unquote(...vars)) ->
          erlang:nif_error(unquote(error_text)).
        """,
        function_name: nif.entrypoint,
        vars: vars,
        marshal_name: marshal_name(nif),
        error_text: error_text,
        error_prongs: error_prongs
      )
    else
      quote_erl(
        """
        unquote(function_name)(unquote(...vars)) ->
          erlang:nif_error(unquote(error_text)).
        """,
        function_name: nif.type.name,
        vars: vars,
        error_text: error_text
      )
    end
  end

  require EEx

  basic = Path.join(__DIR__, "../templates/basic.zig.eex")
  EEx.function_from_file(:defp, :basic, basic, [:assigns])

  basic_raw_zig = Path.join(__DIR__, "../templates/basic_raw_zig.eex")
  EEx.function_from_file(:defp, :basic_raw_zig, basic_raw_zig, [:assigns])

  def render_zig(nif = %{raw: :zig}), do: basic_raw_zig(nif)
  # note a raw "c" function does not need to have any changes made.
  def render_zig(nif = %{raw: :c}), do: ""
  def render_zig(nif), do: basic(nif)
end
