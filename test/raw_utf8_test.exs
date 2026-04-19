defmodule RawUtf8Test do
  use ExUnit.Case

  test "parses raw utf8 characters in text and component values" do
    vcard = """
    BEGIN:VCARD
    VERSION:4.0
    FN:A Magalhães
    N:Magalhães;A;;;
    END:VCARD
    """

    assert [parsed_vcard] = VCard.Parser.parse(vcard)

    assert Keyword.get(parsed_vcard, :fn)[:value] == "A Magalhães"
    assert Keyword.get(parsed_vcard, :n)[:value] == ["Magalhães", "A", "", "", ""]
  end

  test "parses unicode token escapes in component values" do
    vcard = """
    BEGIN:VCARD
    VERSION:4.0
    FN:A Magalhães
    N:Magalh<U+00E3>es;A;;;
    END:VCARD
    """

    assert [parsed_vcard] = VCard.Parser.parse(vcard)

    assert Keyword.get(parsed_vcard, :n)[:value] == ["Magalhães", "A", "", "", ""]
  end

  test "keeps escaped ascii delimiters working alongside raw utf8" do
    vcard =
      "BEGIN:VCARD\r\n" <>
        "VERSION:4.0\r\n" <>
        "FN:A Magalhães\r\n" <>
        "N:Magalhães\\;Filho;A\\, Jr.;;;\r\n" <>
        "END:VCARD\r\n"

    assert [parsed_vcard] = VCard.Parser.parse(vcard)

    assert Keyword.get(parsed_vcard, :n)[:value] == [
             "Magalhães;Filho",
             "A, Jr.",
             "",
             "",
             ""
           ]
  end
end
