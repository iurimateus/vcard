defmodule VCard.Parser.Params do
  import NimbleParsec
  import VCard.Parser.Core
  import VCard.Parser.Types

  NimbleCSV.define(VCard.Parser.Params.Splitter, separator: ",", escape: "\"")
  alias VCard.Parser.Params.Splitter

  @all_param_types [
    :language,
    :value,
    :pref,
    :pid,
    :type,
    :geo,
    :tz,
    :sort_as,
    :calscale,
    :encoding,
    :any
  ]

  # Pre-compiled param name matchers to avoid re-inlining anycase_string
  defparsec(:value_name, anycase_string("value"), export_combinator: true)
  defparsec(:pid_name, anycase_string("pid"), export_combinator: true)
  defparsec(:pref_name, anycase_string("pref"), export_combinator: true)
  defparsec(:altid_name, anycase_string("altid"), export_combinator: true)
  defparsec(:mediatype_name, anycase_string("mediatype"), export_combinator: true)
  defparsec(:type_name, anycase_string("type"), export_combinator: true)
  defparsec(:language_name, anycase_string("language"), export_combinator: true)
  defparsec(:sort_as_name, anycase_string("sort_as"), export_combinator: true)
  defparsec(:encoding_name, anycase_string("encoding"), export_combinator: true)
  defparsec(:calscale_name, anycase_string("calscale"), export_combinator: true)
  defparsec(:label_name, anycase_string("label"), export_combinator: true)
  defparsec(:geo_name, anycase_string("geo"), export_combinator: true)
  defparsec(:tz_name, anycase_string("tz"), export_combinator: true)

  # ---- Pre-compiled full param combinators ----
  # These combine param name + value parsing for each param type.
  # Using parsec refs avoids re-inlining the entire param value logic.

  defparsec(
    :value_param,
    parsec({__MODULE__, :value_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :value_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :value_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :pref_param,
    parsec({__MODULE__, :pref_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :pref_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :pref_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :pid_param,
    parsec({__MODULE__, :pid_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :pid_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :pid_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :altid_param,
    parsec({__MODULE__, :altid_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :any_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :any_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :mediatype_param,
    parsec({__MODULE__, :mediatype_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :mediatype_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :mediatype_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :type_param,
    parsec({__MODULE__, :type_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :type_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :type_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :language_param,
    parsec({__MODULE__, :language_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :any_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :any_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :sort_as_param,
    parsec({__MODULE__, :sort_as_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :sort_as_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :sort_as_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :encoding_param,
    parsec({__MODULE__, :encoding_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :encoding_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :encoding_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :calscale_param,
    parsec({__MODULE__, :calscale_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :calscale_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :calscale_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :label_param,
    parsec({__MODULE__, :label_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :any_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :any_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :geo_param,
    parsec({__MODULE__, :geo_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :geo_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :geo_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :tz_param,
    parsec({__MODULE__, :tz_name})
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :tz_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :tz_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  defparsec(
    :any_param,
    x_name()
    |> ignore(equals())
    |> concat(parsec({VCard.Parser.ParamValues, :any_pv}))
    |> repeat(ignore(comma()) |> concat(parsec({VCard.Parser.ParamValues, :any_pv})))
    |> reduce(:reduce_param),
    export_combinator: true
  )

  # Generates a `choice/2` parser for the desired
  # parameters
  def params(valid_params \\ @all_param_types) do
    repeat(ignore(semicolon()) |> concat(param(valid_params)))
    |> reduce(:group_and_downcase_params)
    |> unwrap_and_tag(:params)
  end

  #    param = language-param / value-param / pref-param / pid-param
  #          / type-param / geo-parameter / tz-parameter / sort-as-param
  #          / calscale-param / any-param
  #      ; Allowed parameters depend on property name.
  #
  #    param-value = *SAFE-CHAR / DQUOTE *QSAFE-CHAR DQUOTE
  #
  #    any-param  = (iana-token / x-name) "=" param-value *("," param-value)
  def param([valid_param]) do
    param(valid_param)
  end

  def param(valid_params) when is_list(valid_params) do
    valid_params
    |> Enum.map(&param/1)
    |> choice()
  end

  def param(valid_param) when is_atom(valid_param) do
    case valid_param do
      :value -> parsec({__MODULE__, :value_param})
      :pref -> parsec({__MODULE__, :pref_param})
      :pid -> parsec({__MODULE__, :pid_param})
      :altid -> parsec({__MODULE__, :altid_param})
      :mediatype -> parsec({__MODULE__, :mediatype_param})
      :type -> parsec({__MODULE__, :type_param})
      :language -> parsec({__MODULE__, :language_param})
      :sort_as -> parsec({__MODULE__, :sort_as_param})
      :encoding -> parsec({__MODULE__, :encoding_param})
      :calscale -> parsec({__MODULE__, :calscale_param})
      :label -> parsec({__MODULE__, :label_param})
      :geo -> parsec({__MODULE__, :geo_param})
      :tz -> parsec({__MODULE__, :tz_param})
      :any -> parsec({__MODULE__, :any_param})
      _ -> parsec({__MODULE__, :any_param})
    end
  end

  # Param name functions now delegate to pre-compiled parsecs
  def value, do: parsec({__MODULE__, :value_name})
  def pid, do: parsec({__MODULE__, :pid_name})
  def pref, do: parsec({__MODULE__, :pref_name})
  def altid, do: parsec({__MODULE__, :altid_name})
  def mediatype, do: parsec({__MODULE__, :mediatype_name})
  def type, do: parsec({__MODULE__, :type_name})
  def language, do: parsec({__MODULE__, :language_name})
  def sort_as, do: parsec({__MODULE__, :sort_as_name})
  def encoding, do: parsec({__MODULE__, :encoding_name})
  def calscale, do: parsec({__MODULE__, :calscale_name})
  def label, do: parsec({__MODULE__, :label_name})
  def geo, do: parsec({__MODULE__, :geo_name})
  def tz, do: parsec({__MODULE__, :tz_name})

  def any do
    parsec({__MODULE__, :any_param})
  end

  def group_and_downcase_params(list) do
    list
    |> Enum.group_by(fn {k, _v} -> k end, fn {_k, v} -> v end)
    |> Map.new(fn {x, y} ->
      case List.flatten(y) do
        [one] -> {x, one}
        other -> {x, other}
      end
    end)
    |> Enum.map(&downcase/1)
    |> Map.new()
  end

  def downcase(list) when is_list(list) do
    Enum.map(list, &downcase/1)
  end

  def downcase({x, y}) do
    {x, downcase(y)}
  end

  def downcase(x) when is_binary(x) do
    String.downcase(x)
  end

  def downcase(x) do
    x
  end

  def split_at_commas(list) do
    Splitter.parse_enumerable(["" | list])
    |> List.flatten()
  end

  def reduce_param([key | values]) do
    {String.downcase(key), unescape(values)}
  end
end
