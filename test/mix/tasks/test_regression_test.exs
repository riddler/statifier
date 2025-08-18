defmodule Mix.Tasks.Test.RegressionTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Mix.Tasks.Test.Regression

  # Create a temporary directory for test fixtures
  @fixtures_dir "test/fixtures/mix_tasks"

  setup do
    # Create fixtures directory
    File.mkdir_p!(@fixtures_dir)

    # Create sample test files for wildcard testing
    File.mkdir_p!("#{@fixtures_dir}/sc/parser")
    File.write!("#{@fixtures_dir}/sc/parser/sample_test.exs", "# sample test")
    File.write!("#{@fixtures_dir}/sc/sample_test.exs", "# sample test")
    File.write!("#{@fixtures_dir}/sc_test.exs", "# main test")

    # Create a test JSON file
    test_json = %{
      "description" => "Test registry",
      "internal_tests" => [
        "#{@fixtures_dir}/sc_test.exs",
        "#{@fixtures_dir}/sc/**/*_test.exs"
      ],
      "scion_tests" => [
        "#{@fixtures_dir}/scion_sample_test.exs"
      ],
      "w3c_tests" => []
    }

    json_path = "#{@fixtures_dir}/test_passing_tests.json"
    File.write!(json_path, Jason.encode!(test_json))

    on_exit(fn ->
      File.rm_rf!(@fixtures_dir)
    end)

    {:ok, json_path: json_path}
  end

  describe "expand_test_patterns/1" do
    test "expands wildcard patterns correctly" do
      patterns = ["#{@fixtures_dir}/sc/**/*_test.exs"]

      result = Regression.expand_test_patterns(patterns)

      assert is_list(result)
      assert length(result) == 2
      assert "#{@fixtures_dir}/sc/parser/sample_test.exs" in result
      assert "#{@fixtures_dir}/sc/sample_test.exs" in result
      # Results should be sorted
      assert result == Enum.sort(result)
    end

    test "includes direct file paths that exist" do
      patterns = ["#{@fixtures_dir}/sc_test.exs"]

      result = Regression.expand_test_patterns(patterns)

      assert result == ["#{@fixtures_dir}/sc_test.exs"]
    end

    test "filters out non-test files from wildcard" do
      # Create a non-test file (doesn't end with _test.exs)
      File.write!("#{@fixtures_dir}/sc/helper.exs", "# not a test")

      patterns = ["#{@fixtures_dir}/sc/**/*.exs"]

      result = Regression.expand_test_patterns(patterns)

      # Should only include files ending with _test.exs
      assert Enum.all?(result, &String.ends_with?(&1, "_test.exs"))
      refute "#{@fixtures_dir}/sc/helper.exs" in result
    end

    test "handles non-existent files gracefully" do
      patterns = ["nonexistent/path/test.exs"]

      output =
        capture_io(:stderr, fn ->
          result = Regression.expand_test_patterns(patterns)
          assert result == []
        end)

      assert output =~ "Test file not found: nonexistent/path/test.exs"
    end

    test "handles mixed pattern types" do
      patterns = [
        # direct file
        "#{@fixtures_dir}/sc_test.exs",
        # wildcard
        "#{@fixtures_dir}/sc/**/*_test.exs",
        # non-existent
        "nonexistent/test.exs"
      ]

      capture_io(:stderr, fn ->
        result = Regression.expand_test_patterns(patterns)

        # 1 direct + 2 wildcard matches
        assert length(result) == 3
        assert "#{@fixtures_dir}/sc_test.exs" in result
        assert "#{@fixtures_dir}/sc/parser/sample_test.exs" in result
        assert "#{@fixtures_dir}/sc/sample_test.exs" in result
      end)
    end

    test "returns empty list for empty input" do
      result = Regression.expand_test_patterns([])
      assert result == []
    end
  end

  describe "load_passing_tests/1" do
    test "loads valid JSON file successfully", %{json_path: json_path} do
      # Use the fixture file directly
      result = Regression.load_passing_tests(json_path)

      assert {:ok, tests} = result
      assert is_map(tests)
      assert Map.has_key?(tests, "internal_tests")
      assert Map.has_key?(tests, "scion_tests")
      assert Map.has_key?(tests, "w3c_tests")
    end

    test "handles missing file gracefully" do
      # Use a non-existent path
      result = Regression.load_passing_tests("nonexistent/path.json")

      assert {:error, reason} = result
      assert reason =~ "File read error"
    end

    test "handles invalid JSON gracefully" do
      # Create temporary invalid JSON file
      invalid_json_path = "#{@fixtures_dir}/invalid.json"
      File.write!(invalid_json_path, "{invalid json")

      result = Regression.load_passing_tests(invalid_json_path)

      assert {:error, reason} = result
      assert reason =~ "JSON decode error"
    end
  end

  # Note: Testing run_tests/2 would require mocking System.cmd/3
  # For now, we focus on the core logic functions that don't have external dependencies
end
