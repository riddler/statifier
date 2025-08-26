defmodule Mix.Tasks.Test.BaselineTest do
  use ExUnit.Case

  alias Mix.Tasks.Test.Baseline

  describe "extract_test_summary/1" do
    test "parses output with excluded count correctly" do
      output = """
      Running ExUnit with seed: 123, max_cases: 16
      Excluding tags: [:scxml_w3]
      Including tags: [:scion]

      ..............

      Finished in 0.5 seconds (0.3s async, 0.2s sync)
      290 tests, 97 failures, 163 excluded
      """

      result = Baseline.extract_test_summary(output)

      # 290 total - 163 excluded = 127 tests run
      # 127 tests run - 97 failures = 30 passing
      assert result == "30/127 passing"
    end

    test "parses output without excluded count (fallback)" do
      output = """
      Running ExUnit with seed: 123, max_cases: 16

      ........

      Finished in 0.1 seconds (0.1s async, 0.0s sync)
      8 tests, 0 failures
      """

      result = Baseline.extract_test_summary(output)

      # 8 total - 0 failures = 8 passing
      assert result == "8/8 passing"
    end

    test "handles zero failures with excluded count" do
      output = """
      Running ExUnit with seed: 456, max_cases: 16
      Excluding tags: [:scion, :scxml_w3]

      ..................

      Finished in 0.2 seconds (0.2s async, 0.0s sync)
      290 tests, 0 failures, 276 excluded
      """

      result = Baseline.extract_test_summary(output)

      # 290 total - 276 excluded = 14 tests run
      # 14 tests run - 0 failures = 14 passing
      assert result == "14/14 passing"
    end

    test "handles plural vs singular test/failure wording" do
      # Test singular forms
      output1 = """
      Finished in 0.1 seconds
      1 test, 1 failure, 0 excluded
      """

      result1 = Baseline.extract_test_summary(output1)
      assert result1 == "0/1 passing"

      # Test mixed singular/plural
      output2 = """
      Finished in 0.1 seconds
      2 tests, 1 failure, 0 excluded
      """

      result2 = Baseline.extract_test_summary(output2)
      assert result2 == "1/2 passing"
    end

    test "handles edge case with all tests excluded" do
      output = """
      Running ExUnit with seed: 789, max_cases: 16
      Excluding tags: [:scion, :scxml_w3]

      Finished in 0.0 seconds (0.0s async, 0.0s sync)
      100 tests, 0 failures, 100 excluded
      """

      result = Baseline.extract_test_summary(output)

      # 100 total - 100 excluded = 0 tests run
      # 0 tests run - 0 failures = 0 passing
      assert result == "0/0 passing"
    end

    test "handles output with extra whitespace and line breaks" do
      output = """

      Running ExUnit with seed: 999

      ..

      Finished in 0.1 seconds
      2   tests,   1   failure,   0   excluded

      """

      result = Baseline.extract_test_summary(output)
      assert result == "1/2 passing"
    end

    test "returns error message for unparseable output" do
      output = """
      This is not valid test output
      No test summary line here
      """

      result = Baseline.extract_test_summary(output)
      assert result == "Unable to parse results"
    end

    test "returns error message for empty output" do
      result = Baseline.extract_test_summary("")
      assert result == "Unable to parse results"
    end

    test "handles complex output with multiple summary-like lines" do
      output = """
      Running ExUnit with seed: 123
      Some other line with 5 tests, 2 failures mentioned

      More output here...

      Finished in 0.5 seconds (0.3s async, 0.2s sync)
      50 tests, 10 failures, 20 excluded
      """

      result = Baseline.extract_test_summary(output)

      # Should match the last/actual summary line
      # 50 total - 20 excluded = 30 tests run
      # 30 tests run - 10 failures = 20 passing
      assert result == "20/30 passing"
    end

    test "handles realistic SCION test output" do
      # Based on actual output from running SCION tests
      output = """
      ==> file_system
      Compiling 7 files (.ex)
      Generated file_system app
      ==> bunt
      Compiling 2 files (.ex) 
      Generated bunt app
      ==> jason
      Compiling 10 files (.ex)
      Generated jason app
      Running ExUnit with seed: 540680, max_cases: 16
      Excluding tags: [:scxml_w3]
      Including tags: [:scion]

      .............

      Finished in 0.02 seconds (0.00s async, 0.02s sync)
      290 tests, 97 failures, 163 excluded
      """

      result = Baseline.extract_test_summary(output)
      assert result == "30/127 passing"
    end
  end
end
