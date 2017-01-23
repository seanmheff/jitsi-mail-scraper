defmodule JitsiScraper do
  use Timex

  @url "http://lists.jitsi.org/pipermail/users/"
  @regex ~r/From (.*) at (.*)  (.*)\nFrom: (.*) at (.*) \(.*\)\nDate.*\nSubject.*\n(.*\n.*\n)?Message-ID.*\n\n/

  def scrape do
    HTTPoison.get!(@url).body
    |> Floki.attribute("tr a", "href")
    |> Enum.filter(fn(url) -> String.match?(url, ~r/2017-.*?.txt.gz/) end)
    |> Enum.map(fn(path) -> HTTPoison.get!(@url <> path).body end)
    |> Enum.map(fn(archive) -> :zlib.gunzip(archive) end)
  end

  def parse(archives) do
    Enum.map archives, fn(archive) ->
      String.split(archive, @regex, include_captures: true, trim: true) # split at the headers
      |> Enum.chunk(2) # combine headers and body
      |> Enum.map(fn(group) -> map_group(group) end)
    end
  end

  defp map_group([ headers | body ]) do
    String.split(headers, "\n", trim: true)
    |> tl # the first header is useless, discard it
    |> Enum.map(fn(header) -> String.split(header, ":", parts: 2) end)
    |> Enum.reduce(%{}, fn(header, acc) -> reduce_headers(header, body, acc) end)
  end

  defp reduce_headers(header, body, acc) do
    [key, value] = header
    acc = case key do
      "From" -> acc
        |> Map.put(:name, parse_name(value))
        |> Map.put(:from, parse_email(value))
      "Date" -> Map.put(acc, :date, parse_date(value))
      "Subject" -> Map.put(acc, :subject, String.trim(value))
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
    Timex.parse!(date, " %a, %e %b %Y %H:%M:%S %z", :strftime)
  end
end
