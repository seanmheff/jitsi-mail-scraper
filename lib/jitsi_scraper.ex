defmodule JitsiScraper do
  use Timex

  @url "http://lists.jitsi.org/pipermail/users/"
  @regex ~r/From (.*) at (.*)  (.*)\nFrom: (.*) at (.*) \(.*\)\nDate.*\n(Subject.*?\n(.*\n)*?)?(In-Reply-To:.*?\n)?(References:.*?\n(.*\n)*?)?Message-ID:.*\n\n/

  def perform do
    scrape() |> parse()
  end

  def scrape do
    HTTPoison.get!(@url).body
    |> Floki.attribute("tr a", "href")
    |> Enum.filter(fn(url) -> String.match?(url, ~r/2016-Nov.*?.txt.gz/) end)
    |> Enum.map(fn(path) -> HTTPoison.get!(@url <> path).body end)
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

  defp reduce_header_item(item, acc) do
    if String.starts_with? item, ["\t", " "] do # if a line starts with a " " it belongs to the previous header
      List.replace_at(acc, -1, List.last(acc) <> item)
    else
      List.insert_at(acc, -1, item)
    end
  end

  defp reduce_message([ key, value|_ ], body, acc) do
    acc = case key do
      "From" -> acc
        |> Map.put(:name, parse_name(value))
        |> Map.put(:from, parse_email(value))
      "Date" -> Map.put(acc, :date, parse_date(value))
      "Subject" -> Map.put(acc, :subject, String.trim(value))
      "In-Reply-To" -> Map.put(acc, :in_reply_to, String.trim(value))
      "References" -> Map.put(acc, :references, parse_references(value))
      "Message-ID" -> Map.put(acc, :message_id, String.trim(value))
      _ -> acc
    end
    Map.put(acc, :body, body)
  end

  defp parse_name(name) do
    Regex.named_captures(~r/.*\((?<name>.*?)\)/, name)["name"]
  end

  defp parse_email(email) do
    matches = Regex.named_captures(~r/ (?<username>.*) at (?<domain>.*?) .*/, email)
    matches["username"] <> "@" <> matches["domain"]
  end

  defp parse_date(date) do
    if Regex.match?(~r/^ \w{3}, \d+ \w{3} \d{4} \d{2}:\d{2}:\d{2} [+-]\d{4}$/, date) do
      Timex.parse!(date, " %a, %e %b %Y %H:%M:%S %z", :strftime)
    else
      Timex.parse!(date, " %a, %e %b %Y %H:%M:%S %z (%Z)", :strftime)
    end
  end

  defp parse_references(references) do
    String.split(references, " ", trim: true)
  end
end
