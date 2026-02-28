defmodule VCard.Parser.Types do
  import NimbleParsec
  import VCard.Parser.Core

  def version_as_float(args) do
    args
    |> Enum.join()
    |> String.to_float()
  end

  # Helper combinators used internally - these are plain def functions
  # available to other modules but NOT callable from defparsec in this module.
  def year, do: integer(4) |> unwrap_and_tag(:year)
  def month, do: integer(2) |> unwrap_and_tag(:month)
  def day, do: integer(2) |> unwrap_and_tag(:day)
  def hour, do: integer(2) |> unwrap_and_tag(:hour)
  def minute, do: integer(2) |> unwrap_and_tag(:minute)
  def second, do: integer(2) |> unwrap_and_tag(:second)
  def utc_designator, do: ascii_char([?Z])
  def time_designator, do: ascii_char([?T])

  def scheme do
    ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-], min: 1)
    |> label("a URI scheme")
  end

  def iana_token, do: alphanum_and_dash()

  # ---- Inline helper expressions for use in defparsec ----
  # Since defparsec runs at module scope, we can't call our own def functions.
  # We use module attributes and inline expressions instead.

  @year_c integer(4) |> unwrap_and_tag(:year)
  @month_c integer(2) |> unwrap_and_tag(:month)
  @day_c integer(2) |> unwrap_and_tag(:day)
  @hour_c integer(2) |> unwrap_and_tag(:hour)
  @minute_c integer(2) |> unwrap_and_tag(:minute)
  @second_c integer(2) |> unwrap_and_tag(:second)
  @utc_designator_c ascii_char([?Z])
  @period_c ascii_char([?.])
  @digit_c ascii_char([?0..?9])
  @semicolon_c ascii_char([?;]) |> label("a semicolon")
  @equals_c ascii_char([?=]) |> label("an equals sign")
  @alphanumeric_c ascii_string([?a..?z, ?A..?Z, ?0..?9], min: 1)
                  |> label("an alphanumeric character")
  @alphanum_and_dash_c ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-], min: 1)
                       |> label("an alphanumeric character or a dash")
  @alphabetic_c ascii_string([?a..?z, ?A..?Z], min: 1) |> label("an alphabetic character")

  # utc-offset = sign hour [minute]
  defparsec(
    :utc_offset_parsec,
    ascii_char([?+, ?-])
    |> concat(@hour_c)
    |> concat(@minute_c)
    |> post_traverse(:calculate_direction),
    export_combinator: true
  )

  # zone = utc-designator / utc-offset
  @zone_c choice([@utc_designator_c, parsec({__MODULE__, :utc_offset_parsec})])

  # date
  defparsec(
    :date_parsec,
    choice([
      @year_c
      |> ignore(ascii_char([?-]))
      |> concat(@month_c)
      |> ignore(ascii_char([?-]))
      |> concat(@day_c),
      @year_c |> optional(@month_c |> concat(@day_c)),
      @year_c |> ignore(ascii_char([?-])) |> concat(@month_c),
      ignore(string("---")) |> concat(@day_c),
      ignore(string("--")) |> concat(@month_c) |> optional(@day_c)
    ]),
    export_combinator: true
  )

  @date_noreduc_c choice([
                    @year_c |> concat(@month_c) |> concat(@day_c),
                    ignore(string("---")) |> concat(@day_c),
                    ignore(string("--")) |> concat(@month_c) |> concat(@day_c)
                  ])
  @date_complete_c @year_c |> concat(@month_c) |> concat(@day_c)

  @time_c choice([
            @hour_c |> optional(@minute_c |> optional(@second_c)) |> optional(@zone_c),
            ignore(ascii_char([?-]))
            |> concat(@minute_c)
            |> optional(@second_c)
            |> optional(@zone_c),
            ignore(string("--")) |> concat(@second_c) |> optional(@zone_c)
          ])

  @time_notrunc_c @hour_c |> optional(@minute_c |> optional(@second_c)) |> optional(@zone_c)
  @time_complete_c @hour_c |> concat(@minute_c) |> concat(@second_c) |> optional(@zone_c)
  @time_designator_c ascii_char([?T])

  @date_time_c @date_noreduc_c |> ignore(@time_designator_c) |> concat(@time_notrunc_c)

  # timestamp
  defparsec(
    :timestamp_parsec,
    @date_complete_c |> ignore(@time_designator_c) |> concat(@time_complete_c),
    export_combinator: true
  )

  # date-and-or-time
  defparsec(
    :date_and_or_time_parsec,
    choice([
      @date_time_c,
      parsec({__MODULE__, :date_parsec}),
      ignore(@time_designator_c) |> concat(@time_c)
    ]),
    export_combinator: true
  )

  # pid
  defparsec(
    :pid_parsec,
    @digit_c |> optional(@period_c |> concat(@digit_c)),
    export_combinator: true
  )

  #    x-name = "x-" 1*(ALPHA / DIGIT / "-")
  #      ; Names that begin with "x-" or "X-" are
  #      ; reserved for experimental use, not intended for released
  #      ; products, or for use in bilateral agreements.
  defparsec(
    :x_name_parsec,
    ascii_string([?x, ?X], min: 1)
    |> ascii_string([?-], min: 1)
    |> concat(@alphanum_and_dash_c)
    |> reduce({Enum, :join, []})
    |> label("an x- prefixed token"),
    export_combinator: true
  )

  # adr_type
  defparsec(
    :adr_type_parsec,
    choice([
      anycase_string("postal"),
      anycase_string("parcel"),
      anycase_string("internet")
    ])
    |> label("a valid address type"),
    export_combinator: true
  )

  # related_type
  defparsec(
    :related_type_parsec,
    choice([
      anycase_string("contact"),
      anycase_string("acquaintance"),
      anycase_string("friend"),
      anycase_string("met"),
      anycase_string("co-worker"),
      anycase_string("colleague"),
      anycase_string("co-resident"),
      anycase_string("neighbor"),
      anycase_string("child"),
      anycase_string("parent"),
      anycase_string("sibling"),
      anycase_string("spouse"),
      anycase_string("kin"),
      anycase_string("muse"),
      anycase_string("crush"),
      anycase_string("date"),
      anycase_string("sweetheart"),
      anycase_string("me"),
      anycase_string("agent"),
      anycase_string("emergency")
    ])
    |> label("a valid related type"),
    export_combinator: true
  )

  # tel_type
  defparsec(
    :tel_type_parsec,
    choice([
      ci_string("text"),
      ci_string("voice"),
      ci_string("fax"),
      ci_string("cell"),
      ci_string("video"),
      ci_string("pager"),
      ci_string("textphone"),
      ci_string("msg"),
      ci_string("iphone"),
      ci_string("main"),
      ci_string("other"),
      parsec({__MODULE__, :x_name_parsec})
    ])
    |> label("a valid tel type"),
    export_combinator: true
  )

  # type_code
  defparsec(
    :type_code_parsec,
    choice([
      anycase_string("work"),
      anycase_string("home"),
      anycase_string("pref"),
      anycase_string("jpeg"),
      parsec({__MODULE__, :adr_type_parsec}),
      parsec({__MODULE__, :tel_type_parsec}),
      parsec({__MODULE__, :related_type_parsec}),
      parsec({__MODULE__, :x_name_parsec}),
      @alphabetic_c
    ])
    |> reduce({Enum, :map, [&String.downcase/1]})
    |> label("a valid type"),
    export_combinator: true
  )

  # mediatype
  defparsec(
    :mediatype_parsec,
    @alphanum_and_dash_c
    |> ascii_string([?/], min: 1)
    |> concat(@alphanum_and_dash_c)
    |> reduce({Enum, :join, []})
    |> label("a valid mediatype"),
    export_combinator: true
  )

  # attribute_list
  defparsec(
    :attribute_list_parsec,
    ignore(@semicolon_c)
    |> concat(@alphanumeric_c)
    |> ignore(@equals_c)
    |> concat(@alphanumeric_c)
    |> reduce(:tuplize)
    |> repeat,
    export_combinator: true
  )

  @unreserved [?0..?9, ?a..?z, ?A..?Z, ?-, ?., ?_, ?~]
  @reserved [?%, ?#, ?/, ?%, ?@, ?:, ??]
  @subdelims [?!, ?$, ?&, ?', ?(, ?), ?*, ?+, ?;, ?,, ?=]

  # uri
  defparsec(
    :uri_parsec,
    ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-], min: 1)
    |> label("a URI scheme")
    |> ignore(
      choice([
        ascii_char([?:]) |> label("a colon"),
        ascii_char([?\\]) |> concat(ascii_char([?:]) |> label("a colon"))
      ])
    )
    |> ascii_string(@unreserved ++ @reserved ++ @subdelims, min: 1)
    |> reduce(:tag_uri)
    |> label("a URI"),
    export_combinator: true
  )

  def tuplize([key, value]) do
    {key, value}
  end

  def tag_uri([scheme, location]) do
    {scheme, location}
  end

  def calculate_direction(rest, [{:minute, minutes}, {:hour, hours}, ?+], context, _, _) do
    {rest, [{:tz_minute_offset, minutes}, {:tz_hour_offset, hours}], context}
  end

  def calculate_direction(rest, [{:minute, minutes}, {:hour, hours}, ?-], context, _, _) do
    {rest, [{:tz_minute_offset, minutes}, {:tz_hour_offset, hours * -1}], context}
  end

  # ---- Legacy wrappers ----
  # These return parsec refs so callers get runtime calls instead of inlining.
  def utc_offset, do: parsec({__MODULE__, :utc_offset_parsec})
  def zone, do: choice([utc_designator(), utc_offset()])
  def date, do: parsec({__MODULE__, :date_parsec})
  def date_noreduc, do: @date_noreduc_c
  def date_complete, do: @date_complete_c
  def time, do: @time_c
  def time_notrunc, do: @time_notrunc_c
  def time_complete, do: @time_complete_c
  def date_time, do: @date_time_c
  def timestamp, do: parsec({__MODULE__, :timestamp_parsec})
  def date_and_or_time, do: parsec({__MODULE__, :date_and_or_time_parsec})
  def pid, do: parsec({__MODULE__, :pid_parsec})
  def x_name, do: parsec({__MODULE__, :x_name_parsec})
  def adr_type, do: parsec({__MODULE__, :adr_type_parsec})
  def related_type, do: parsec({__MODULE__, :related_type_parsec})
  def tel_type, do: parsec({__MODULE__, :tel_type_parsec})
  def type_code, do: parsec({__MODULE__, :type_code_parsec})
  def mediatype, do: parsec({__MODULE__, :mediatype_parsec})
  def attribute_list, do: parsec({__MODULE__, :attribute_list_parsec})
  def uri, do: parsec({__MODULE__, :uri_parsec})
end
