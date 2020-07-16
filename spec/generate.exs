defmodule SpecGenerator do
  def process(language, touchfile) do
    full_touchfile = Path.expand(touchfile, ".")

    IO.puts("Hi from Elixir: #{language} #{full_touchfile}")

    File.touch!(full_touchfile)
  end
end

[language, touchfile] = System.argv()
SpecGenerator.process(language, touchfile)
