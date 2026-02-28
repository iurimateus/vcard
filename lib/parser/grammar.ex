defmodule VCard.Parser.Grammar do
  import NimbleParsec
  import VCard.Parser.Core
  import VCard.Parser.Property
  import VCard.Parser.Params, only: [group_and_downcase_params: 1]

  # vcard-entity = 1*vcard
  #
  #    vcard = "BEGIN:VCARD" CRLF
  #            "VERSION:4.0" CRLF
  #            1*contentline
  #            "END:VCARD" CRLF
  #      ; A vCard object MUST include the VERSION and FN properties.
  #      ; VERSION MUST come immediately after BEGIN:VCARD.

  def begin_line do
    anycase_string("begin:vcard")
    |> concat(crlf())
    |> ignore
    |> label("\"BEGIN:VCARD\" as the first line of a vcard")
  end

  def end_line do
    anycase_string("end:vcard")
    |> concat(crlf())
    |> ignore
    |> label("\"END:VCARD\" as the last line of a vcard")
  end

  #    contentline = [group "."] name *(";" param) ":" value CRLF
  #      ; When parsing a content line, folded lines must first
  #      ; be unfolded according to the unfolding procedure
  #      ; described in Section 3.2.
  #      ; When generating a content line, lines longer than 75
  #      ; characters SHOULD be folded according to the folding
  #      ; procedure described in Section 3.2.
  #
  def content_line do
    optional(group() |> ignore(period()))
    |> concat(property())
    |> ignore(crlf())
    |> reduce(:combine_group_and_property)
  end

  def combine_group_and_property([{:group, group}, {property, args}]) do
    {property, Keyword.put(args, :group, group)}
  end

  def combine_group_and_property([{property, args}]) do
    {property, Keyword.put(args, :group, "_default")}
  end

  #    group = 1*(ALPHA / DIGIT / "-")
  def group do
    alphanum_and_dash()
    |> unwrap_and_tag(:group)
  end

  #    name  = "SOURCE" / "KIND" / "FN" / "N" / "NICKNAME"
  #          / "PHOTO" / "BDAY" / "ANNIVERSARY" / "GENDER" / "ADR" / "TEL"
  #          / "EMAIL" / "IMPP" / "LANG" / "TZ" / "GEO" / "TITLE" / "ROLE"
  #          / "LOGO" / "ORG" / "MEMBER" / "RELATED" / "CATEGORIES"
  #          / "NOTE" / "PRODID" / "REV" / "SOUND" / "UID" / "CLIENTPIDMAP"
  #          / "URL" / "KEY" / "FBURL" / "CALADRURI" / "CALURI" / "XML"
  #          / iana-token / x-name

  #      ; Parsing of the param and value is based on the "name" as
  #      ; defined in ABNF sections below.
  #      ; Group and name are case-insensitive.
  def property do
    choice([
      known_property(),
      x_property()
    ])
    |> label("a vcard property name")
    |> reduce(:tag_and_unescape_property)
  end

  def tag_and_unescape_property([name | args]) do
    {_, args} =
      Keyword.get_and_update(args, :value, fn current_value ->
        {current_value, unescape(current_value)}
      end)

    if is_atom(name) do
      {name, args}
    else
      {String.downcase(name), args}
    end
  end

  # Known properties are split across three sub-modules (Props1, Props2,
  # Props3), each holding ~12 defparsec definitions. Each parsec/1 call here
  # creates a call site (reference, not inline) to the compiled parsec.
  #
  # Ordering constraints:
  #   - "nickname" and "note" before "n" (longer prefix tried first)
  #   - "caladruri" before "caluri"
  alias VCard.Parser.Grammar.Props1
  alias VCard.Parser.Grammar.Props2
  alias VCard.Parser.Grammar.Props3

  def known_property do
    choice([
      parsec({Props1, :version}),
      parsec({Props1, :source}),
      parsec({Props1, :kind}),
      parsec({Props1, :fn_}),
      parsec({Props1, :nickname}),
      parsec({Props1, :photo}),
      parsec({Props1, :bday}),
      parsec({Props1, :anniversary}),
      parsec({Props1, :gender}),
      parsec({Props1, :adr}),
      parsec({Props1, :tel}),
      parsec({Props1, :email}),
      parsec({Props2, :impp}),
      parsec({Props2, :lang}),
      parsec({Props2, :tz}),
      parsec({Props2, :geo}),
      parsec({Props2, :title}),
      parsec({Props2, :role}),
      parsec({Props2, :logo}),
      parsec({Props2, :org}),
      parsec({Props2, :member}),
      parsec({Props2, :related}),
      parsec({Props2, :categories}),
      parsec({Props2, :note}),
      parsec({Props3, :prodid}),
      parsec({Props3, :rev}),
      parsec({Props3, :sound}),
      parsec({Props3, :uid}),
      parsec({Props3, :clientpidmap}),
      parsec({Props3, :url}),
      parsec({Props3, :key}),
      parsec({Props3, :fburl}),
      parsec({Props3, :caladruri}),
      parsec({Props3, :caluri}),
      parsec({Props3, :xml}),
      parsec({Props3, :n})
    ])
  end

  defmodule Props1 do
    defparsec(:version, anycase_string("version") |> replace(:version) |> concat(version()),
      export_combinator: true
    )

    defparsec(:source, anycase_string("source") |> replace(:source) |> concat(source()),
      export_combinator: true
    )

    defparsec(:kind, anycase_string("kind") |> replace(:kind) |> concat(kind()),
      export_combinator: true
    )

    defparsec(:fn_, anycase_string("fn") |> replace(:fn) |> concat(fn_()),
      export_combinator: true
    )

    defparsec(:nickname, anycase_string("nickname") |> replace(:nickname) |> concat(nickname()),
      export_combinator: true
    )

    defparsec(:photo, anycase_string("photo") |> replace(:photo) |> concat(photo()),
      export_combinator: true
    )

    defparsec(:bday, anycase_string("bday") |> replace(:bday) |> concat(bday()),
      export_combinator: true
    )

    defparsec(
      :anniversary,
      anycase_string("anniversary") |> replace(:anniversary) |> concat(anniversary()),
      export_combinator: true
    )

    defparsec(:gender, anycase_string("gender") |> replace(:gender) |> concat(gender()),
      export_combinator: true
    )

    defparsec(:adr, anycase_string("adr") |> replace(:adr) |> concat(adr()),
      export_combinator: true
    )

    defparsec(:tel, anycase_string("tel") |> replace(:tel) |> concat(tel()),
      export_combinator: true
    )

    defparsec(:email, anycase_string("email") |> replace(:email) |> concat(email()),
      export_combinator: true
    )
  end

  defmodule Props2 do
    @moduledoc false
    defparsec(:impp, anycase_string("impp") |> replace(:impp) |> concat(impp()),
      export_combinator: true
    )

    defparsec(:lang, anycase_string("lang") |> replace(:lang) |> concat(lang()),
      export_combinator: true
    )

    defparsec(:tz, anycase_string("tz") |> replace(:tz) |> concat(tz()), export_combinator: true)

    defparsec(:geo, anycase_string("geo") |> replace(:geo) |> concat(geo()),
      export_combinator: true
    )

    defparsec(:title, anycase_string("title") |> replace(:title) |> concat(title()),
      export_combinator: true
    )

    defparsec(:role, anycase_string("role") |> replace(:role) |> concat(role()),
      export_combinator: true
    )

    defparsec(:logo, anycase_string("logo") |> replace(:logo) |> concat(logo()),
      export_combinator: true
    )

    defparsec(:org, anycase_string("org") |> replace(:org) |> concat(org()),
      export_combinator: true
    )

    defparsec(:member, anycase_string("member") |> replace(:member) |> concat(member()),
      export_combinator: true
    )

    defparsec(:related, anycase_string("related") |> replace(:related) |> concat(related()),
      export_combinator: true
    )

    defparsec(
      :categories,
      anycase_string("categories") |> replace(:categories) |> concat(categories()),
      export_combinator: true
    )

    defparsec(:note, anycase_string("note") |> replace(:note) |> concat(note()),
      export_combinator: true
    )
  end

  defmodule Props3 do
    @moduledoc false

    defparsec(:prodid, anycase_string("prodid") |> replace(:prodid) |> concat(prodid()),
      export_combinator: true
    )

    defparsec(:rev, anycase_string("rev") |> replace(:rev) |> concat(rev()),
      export_combinator: true
    )

    defparsec(:sound, anycase_string("sound") |> replace(:sound) |> concat(sound()),
      export_combinator: true
    )

    defparsec(:uid, anycase_string("uid") |> replace(:uid) |> concat(uid()),
      export_combinator: true
    )

    defparsec(
      :clientpidmap,
      anycase_string("clientpidmap") |> replace(:clientpidmap) |> concat(clientpidmap()),
      export_combinator: true
    )

    defparsec(:url, anycase_string("url") |> replace(:url) |> concat(url()),
      export_combinator: true
    )

    defparsec(:key, anycase_string("key") |> replace(:key) |> concat(key()),
      export_combinator: true
    )

    defparsec(:fburl, anycase_string("fburl") |> replace(:fburl) |> concat(fburl()),
      export_combinator: true
    )

    # caladruri must come before caluri (longer prefix matched first)
    defparsec(
      :caladruri,
      anycase_string("caladruri") |> replace(:caladruri) |> concat(caladruri()),
      export_combinator: true
    )

    defparsec(:caluri, anycase_string("caluri") |> replace(:caluri) |> concat(caluri()),
      export_combinator: true
    )

    defparsec(:xml, anycase_string("xml") |> replace(:xml) |> concat(xml()),
      export_combinator: true
    )

    # n must come last to avoid shadowing "nickname" and "note"
    defparsec(:n, anycase_string("n") |> replace(:n) |> concat(n()), export_combinator: true)
  end
end
