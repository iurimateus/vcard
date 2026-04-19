defmodule VCard.Parser.Core do
  import NimbleParsec

  @cr 0x0D
  @lf 0x0A

  # Allow NL line ends for simpler compatibility
  def crlf do
    choice([
      ascii_char([@cr]) |> ascii_char([@lf]),
      ascii_char([@lf])
    ])
    |> label("a newline (either CRLF or LF)")
  end

  def colon do
    ascii_char([?:])
    |> label("a colon")
  end

  def semicolon do
    ascii_char([?;])
    |> label("a semicolon")
  end

  def period do
    ascii_char([?.])
    |> label("a dot character")
  end

  def comma do
    ascii_char([?,])
    |> label("a comma")
  end

  def digit do
    ascii_char([?0..?9])
    |> label("a decimal digit")
  end

  def equals do
    ascii_char([?=])
    |> label("an equals sign")
  end

  def dquote do
    ascii_char([?"])
    |> label("a double quote character")
  end

  def hex_string do
    ascii_string([?a..?f, ?A..?F, ?0..?9], min: 1)
    |> label("a hexidecimal digit")
  end

  def alphanum_and_dash do
    ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-], min: 1)
    |> label("an alphanumeric character or a dash")
  end

  def alphabetic do
    ascii_string([?a..?z, ?A..?Z], min: 1)
    |> label("an alphabetic character")
  end

  def alphanumeric do
    ascii_string([?a..?z, ?A..?Z, ?0..?9], min: 1)
    |> label("an alphanumeric character")
  end

  def ci_string(str) do
    down = String.downcase(str)
    up = String.upcase(str)

    choice([
      string(down),
      string(up)
    ])
  end

  def anycase_string(string) do
    string
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.reverse()
    |> char_piper()
    |> reduce({List, :to_string, []})
  end

  defp char_piper([c]) when c in ?A..?Z do
    c
    |> both_cases()
    |> ascii_char()
  end

  defp char_piper([c | rest]) when c in ?A..?Z do
    rest
    |> char_piper()
    |> ascii_char(both_cases(c))
  end

  defp char_piper([c]) do
    ascii_char([c])
  end

  defp char_piper([c | rest]) do
    rest
    |> char_piper
    |> ascii_char([c])
  end

  defp both_cases(c) do
    [c, c + 32]
  end

  # ---- Pre-compiled combinators ----
  # These are compiled once and referenced via parsec({VCard.Parser.Core, :name})
  # to avoid re-inlining at every use site.
  #
  # NOTE: defparsec runs at module scope (compile time), so we inline the
  # NimbleParsec combinator expressions directly rather than calling this
  # module's own `def` functions (which aren't available yet).

  #    NON-ASCII = UTF8-2 / UTF8-3 / UTF8-4
  # Legacy NON-ASCII token support. Raw UTF-8 codepoints are accepted by the
  # text/component parsers below via @raw_utf8_char.
  defparsec(
    :non_ascii_parsec,
    ignore(string("<"))
    |> ignore(ascii_char([?U, ?u]))
    |> ignore(string("+"))
    |> concat(ascii_string([?a..?f, ?A..?F, ?0..?9], min: 1))
    |> ignore(string(">"))
    |> reduce(:convert_utf8),
    export_combinator: true
  )

  #    SAFE-CHAR = WSP / "!" / %x23-39 / %x3C-7E / NON-ASCII
  #      ; Any character except CTLs, DQUOTE, ";", ":"
  #      ; ALSO ALLOW &NBSP 0xa0 since Apple Contacts generates it
  defparsec(
    :safe_string_parsec,
    choice([
      parsec({__MODULE__, :non_ascii_parsec}),
      utf8_char([160]),
      ascii_char([0x20, 0x09, ?!, 0x23..0x39, 0x3C..0x7E])
    ])
    |> times(min: 1)
    |> reduce({List, :to_string, []}),
    export_combinator: true
  )

  #    QSAFE-CHAR = WSP / "!" / %x23-7E / NON-ASCII
  #      ; Any character except CTLs, DQUOTE
  #      ; ALSO ALLOW &NBSP 0xa0 since Apple Contacts generates it
  defparsec(
    :qsafe_string_parsec,
    choice([
      parsec({__MODULE__, :non_ascii_parsec}),
      ascii_char([0x20, 0x09, ?!, 0x23..0x7E])
    ])
    |> times(min: 1)
    |> reduce({List, :to_string, []}),
    export_combinator: true
  )

  defparsec(
    :quoted_string_parsec,
    ignore(ascii_char([?"]))
    |> concat(parsec({__MODULE__, :qsafe_string_parsec}))
    |> ignore(ascii_char([?"])),
    export_combinator: true
  )

  # text = *TEXT-CHAR
  #
  # TEXT-CHAR = "\\" / "\," / "\n" / WSP / NON-ASCII
  #           / %x21-2B / %x2D-5B / %x5D-7E
  #    ; Backslashes, commas, and newlines must be encoded.
  @unescaped_char [0x20, 0x09, 0x21..0x2B, 0x2D..0x5B, 0x5D..0x7E]
  @escaped_char [?\\, ?,, 0x0D]
  # Allow only non-ASCII UTF-8 codepoints here.
  #
  # 0x80..0x10FFFF covers characters above the ASCII range, including NBSP and
  # letters such as "ã". ASCII bytes (0x00..0x7F) are still constrained by the
  # explicit RFC-derived ascii_char(...) ranges below, so delimiters and
  # control characters such as ",", ";", ":", "\\", CR, and LF do not become
  # accidentally valid just because we accept raw UTF-8 input. This parser is
  # intentionally broad for non-ASCII codepoints; it preserves the ASCII
  # rules without trying to blacklist every non-ASCII control or format
  # character.
  @raw_utf8_char [0x80..0x10FFFF]

  defparsec(
    :text_parsec,
    choice([
      parsec({__MODULE__, :non_ascii_parsec}),
      utf8_char(@raw_utf8_char),
      ascii_char([?\\]) |> ascii_char(@escaped_char ++ @unescaped_char),
      ascii_char(@unescaped_char)
    ])
    |> repeat
    |> reduce({List, :to_string, []})
    |> post_traverse(:unescape),
    export_combinator: true
  )

  defparsec(
    :text_list_parsec,
    parsec({__MODULE__, :text_parsec})
    |> repeat(
      ignore(ascii_char([?,]) |> label("a comma"))
      |> concat(parsec({__MODULE__, :text_parsec}))
    ),
    export_combinator: true
  )

  # component = "\\" / "\," / "\;" / "\n" / WSP / NON-ASCII
  #           / %x21-2B / %x2D-3A / %x3C-5B / %x5D-7E
  @unescaped_component [0x20, 0x09, 0x21..0x2B, 0x2D..0x3A, 0x3C..0x5B, 0x5D..0x7E]
  @escaped_component [?\\, ?,, ?;, 0x0D]

  defparsec(
    :component_parsec,
    choice([
      parsec({__MODULE__, :non_ascii_parsec}),
      utf8_char(@raw_utf8_char),
      ascii_char([?\\]) |> ascii_char(@escaped_component),
      ascii_char(@unescaped_component)
    ])
    |> repeat
    |> reduce({List, :to_string, []})
    |> post_traverse(:unescape)
    |> label("bad component"),
    export_combinator: true
  )

  # list-component = component *(";" component)
  defparsec(
    :list_component_parsec,
    parsec({__MODULE__, :component_parsec})
    |> repeat(
      ignore(ascii_char([?;]) |> label("a semicolon"))
      |> optional(parsec({__MODULE__, :component_parsec}))
    ),
    export_combinator: true
  )

  # ---- Legacy wrappers ----
  def quoted_string, do: parsec({__MODULE__, :quoted_string_parsec})
  def safe_string, do: parsec({__MODULE__, :safe_string_parsec})
  def qsafe_string, do: parsec({__MODULE__, :qsafe_string_parsec})
  def non_ascii, do: parsec({__MODULE__, :non_ascii_parsec})
  def text, do: parsec({__MODULE__, :text_parsec})
  def text_list, do: parsec({__MODULE__, :text_list_parsec})
  def component, do: parsec({__MODULE__, :component_parsec})
  def list_component, do: parsec({__MODULE__, :list_component_parsec})

  def default_nil(rest, context, _, _) do
    {rest, [nil], context}
  end

  def unescape(rest, args, context, _, _) do
    {rest, unescape(args), context}
  end

  def unescape(values) when is_list(values) do
    Enum.map(values, &unescape/1)
  end

  def unescape(values) when is_tuple(values) do
    values
  end

  def unescape(""), do: ""
  def unescape(<<"\\n", rest::binary>>), do: "\n" <> unescape(rest)
  def unescape(<<"\\r", rest::binary>>), do: "\r" <> unescape(rest)
  def unescape(<<"\\,", rest::binary>>), do: "," <> unescape(rest)
  def unescape(<<"\\;", rest::binary>>), do: ";" <> unescape(rest)
  def unescape(<<"\\\\", rest::binary>>), do: "\\" <> unescape(rest)

  # Apple address book annotations
  def unescape(<<"_$!<", rest::binary>>), do: unescape(rest)
  def unescape(<<">!$_">>), do: ""

  def unescape(<<"\\", c::binary-size(1), rest::binary>>), do: c <> unescape(rest)
  def unescape(<<c::binary-size(1), rest::binary>>), do: c <> unescape(rest)

  def unescape(values) do
    values
  end

  def convert_utf8(args) do
    args
    |> Enum.map(fn x ->
      {y, ""} = Integer.parse(x, 16)
      y
    end)
    |> List.to_string()
  end
end
