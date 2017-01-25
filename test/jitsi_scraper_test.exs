defmodule JitsiScraperTest do
  use ExUnit.Case
  doctest JitsiScraper

  @subject File.read!("./test/fixtures/subject.txt")
  @one_reference File.read!("./test/fixtures/one_reference.txt")
  @multiple_references File.read!("./test/fixtures/multiple_references.txt")

  describe "JitsiScraper.parse_name/1" do
    test "it returns nil when it cant parse the data" do
      email = JitsiScraper.parse_name("sdfsd")
      assert email == nil
    end

    test "can return a name address" do
      email = JitsiScraper.parse_name(" mathieu at clabaut.net (Mathieu Clabaut)")
      assert email == "Mathieu Clabaut"
    end
  end

  describe "JitsiScraper.parse_email/1" do
    test "it returns nil when it cant parse the data" do
      email = JitsiScraper.parse_email("sdfsd")
      assert email == nil
    end

    test "can return an email address" do
      email = JitsiScraper.parse_email(" mathieu at clabaut.net (Mathieu Clabaut)")
      assert email == "mathieu@clabaut.net"
    end
  end

  describe "JitsiScraper.parse_date/1" do
    test "it returns nil when it cant parse the date" do
      date_obj = JitsiScraper.parse_date("bad date")
      assert date_obj == nil
    end

    test "it can return a DateTime object" do
      date_obj = JitsiScraper.parse_date(" Thu, 01 Dec 2016 09:23:31 +0100")
      assert date_obj.day == 1
      assert date_obj.month == 12
      assert date_obj.year == 2016
      assert date_obj.hour == 9
      assert date_obj.minute == 23
      assert date_obj.second == 31
      assert date_obj.time_zone == "Etc/GMT-1"
    end
  end

  describe "JitsiScraper.parse_subject/1" do
    test "it removes the subject prefix" do
      subject = JitsiScraper.parse_subject(@subject)
      assert !String.starts_with? subject, "[jitsi-users]"
    end

    test "it removes all tab characters" do
      subject = JitsiScraper.parse_subject(@subject)
      assert !String.contains? subject, "\t"
    end
  end

  describe "JitsiScraper.parse_references/1" do
    test "it can handle one reference" do
      references = JitsiScraper.parse_references(@one_reference)
      assert length(references) == 1
    end

    test "it can handle multiple references" do
      references = JitsiScraper.parse_references(@multiple_references)
      assert length(references) == 4
    end
  end
end
