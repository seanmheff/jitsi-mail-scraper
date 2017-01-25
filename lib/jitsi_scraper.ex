defmodule JitsiScraper do
  use Timex

  @regex ~r/From (.*) at (.*)  (.*)\nFrom: (.*) at (.*) \(.*\)\nDate.*\n(Subject.*?\n(.*\n)*?)?(In-Reply-To:.*?\n)?(References:.*?\n(.*\n)*?)?Message-ID:.*\n\n/
  @urls %{
    :dev => "http://lists.jitsi.org/pipermail/dev/",
    :users => "http://lists.jitsi.org/pipermail/users/"
  }

  def get_current_month(mailing_list) do
    month = Timex.today.month |> Timex.month_shortname
    year = Timex.today.year
    scrape(mailing_list, month, year) |> parse()
  end

  def get_all(mailing_list) do
    scrape(mailing_list, ".*", ".*") |> parse()
  end

  def scrape(mailing_list, month, year) do
    HTTPoison.get!(@urls[mailing_list]).body
    |> Floki.attribute("tr a", "href")
    |> Enum.filter(fn(url) -> String.match?(url, ~r/#{year}-#{month}.*?.txt.gz/) end)
    |> Enum.map(fn(path) -> HTTPoison.get!(@urls[mailing_list] <> path).body end)
    |> Enum.map(fn(archive) -> :zlib.gunzip(archive) end)
  end

  def parse(archives) do
    data = Enum.map archives, fn(archive) ->
      String.split(archive, @regex, include_captures: true, trim: true) # split at the headers
      |> Enum.chunk(2) # combine headers and body for each message
      |> Enum.map(fn(message) -> map_message(message) end)
    end
    Enum.reduce(data, [], fn(archive, acc) -> archive ++ acc end)
  end

  def map_message([ headers, body|_ ]) do
    headers
    |> String.split("\n", trim: true) # split the headers at each newline
    |> tl # ignore the first header
    |> Enum.reduce([], fn(item, acc) -> reduce_header_item(item, acc) end) # handle multi-line headers
    |> Enum.map(fn(header) -> String.split(header, ":", parts: 2) end)
    |> Enum.reduce(%{}, fn(header, acc) -> reduce_message(header, body, acc) end)
  end

  def reduce_header_item(item, headers) do
    # if a line starts with whitespace, it belongs to the previous header
    if String.starts_with? item, ["\t", " "] do
      List.replace_at(headers, -1, List.last(headers) <> item)
    else
      List.insert_at(headers, -1, item)
    end
  end

  def reduce_message([ key, value|_ ], body, acc) do
    acc = case key do
      "From" -> acc
        |> Map.put(:name, parse_name(value))
        |> Map.put(:from, parse_email(value))
      "Date" -> Map.put(acc, :date, parse_date(value))
      "Subject" -> Map.put(acc, :subject, parse_subject(value))
      "In-Reply-To" -> Map.put(acc, :in_reply_to, String.trim(value))
      "References" -> Map.put(acc, :references, parse_references(value))
      "Message-ID" -> Map.put(acc, :message_id, String.trim(value))
      _ -> acc
    end
    Map.put(acc, :body, body)
  end

  def parse_name(name) do
    case Regex.named_captures(~r/.*\((?<name>.*?)\)/, name) do
      %{ "name" => name } -> name
      _ -> nil
    end
  end

  def parse_email(email) do
    case Regex.named_captures(~r/ (?<username>.*) at (?<domain>.*?) .*/, email) do
      %{ "username" => username, "domain" => domain } -> username <> "@" <> domain
      _ -> nil
    end
  end

  def parse_date(date) do
    case Regex.run(~r/^ (\w{3}, \d+ \w{3} \d{4} \d{2}:\d{2}:\d{2} [+-]\d{4})/, date) do
      [ _, match|_ ] -> Timex.parse!(match, "%a, %e %b %Y %H:%M:%S %z", :strftime)
      nil -> nil
    end
  end

  def parse_subject(subject) do
    subject
    |> String.trim
    |> String.replace("\t", " ")
    |> String.split(" ", parts: 2)
    |> List.last
  end

  def parse_references(references) do
    String.split(references, " ", trim: true)
  end
end
