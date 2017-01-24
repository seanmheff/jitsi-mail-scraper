defmodule JitsiScraperTest do
  use ExUnit.Case
  doctest JitsiScraper

  basic = File.read!("./test/fixtures/basic.txt")

  describe "JitsiScraper.parser_header/1" do
    test "it disgards the first 'From' header" do
      response = JitsiScraper.parser_header basic
    end

    test "it parses the second 'From' header" do
    end

    test "it parses the 'Date' header" do
    end

    test "it parses the 'Subject' header" do
    end

    test "it parses the 'Subject' header when it spans multiple lines" do
    end

    test "it can parse the optional 'In-Reply-To' header" do
    end

    test "it can parse the optional 'References' header" do
    end

    test "it can parse the optional 'References' header when it spans multiple lines" do
    end

    test "it parses the 'Message-ID' header" do
    end
  end
end
