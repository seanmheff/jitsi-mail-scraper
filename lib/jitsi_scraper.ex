defmodule JitsiScraper do
  def scrape do
    url = "http://lists.jitsi.org/pipermail/users/"
    body = HTTPoison.get!(url).body

    # Get the links to download on this page
    hrefs = Floki.attribute(body, "tr a", "href")

    # Remove links we dont care about
    gzipped_archives_paths = Enum.filter hrefs, fn(url) ->
      String.match?(url, ~r/\.*?.txt.gz/)
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
    Enum.each archives, fn(archive) ->
      # Split the messages before at the email headers
      [ _ | messages ] = String.split(archive, regex, include_captures: true)

      # Chunk the headers and messages into lists
      Enum.chunk(messages, 2) |> Enum.each fn(group) ->
      end
    end
  end
end
