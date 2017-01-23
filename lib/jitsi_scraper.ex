defmodule JitsiScraper do
  use Timex

  def scrape do
    url = "http://lists.jitsi.org/pipermail/users/"
    body = HTTPoison.get!(url).body

    # Get the links to download on this page
    hrefs = Floki.attribute(body, "tr a", "href")

    # Remove links we dont care about
    gzipped_archives_paths = Enum.filter hrefs, fn(url) ->
      #String.match?(url, ~r/\.*?.txt.gz/)
      String.match?(url, ~r/2017-.*?.txt.gz/)
    end

    # GET gzip'd archives
    gzipped_archives = Enum.map gzipped_archives_paths, fn(path) ->
      HTTPoison.get!(url <> path).body
    end

    # Uncompress all the archives and return
    Enum.map gzipped_archives, fn(archive) ->
      :zlib.gunzip(archive)
    end
  end

  def parse(archives) do
    regex = ~r/From (.*) at (.*)  (.*)\nFrom: (.*) at (.*) \(.*\)\nDate.*\nSubject.*\n(.*\n.*\n)?Message-ID.*\n\n/
    Enum.map archives, fn(archive) ->
      # Split the messages before at the email headers
      [ _ | messages ] = String.split(archive, regex, include_captures: true)

      # Chunk the headers and messages into lists and maybe update the DB
      Enum.chunk(messages, 2) |> Enum.map(fn(group) -> map_group(group) end)
    end
  end

  defp map_group([ headers | body ]) do
    # Split up the headers into their individual lines
    # Ignore the first one. It's useless to us.
    headers = tl(String.split(headers, "\n", trim: true)) |> Enum.map(fn(header) ->
      String.split(header, ":", parts: 2)
    end)

    Enum.reduce headers, %{}, fn(header, acc) ->
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
