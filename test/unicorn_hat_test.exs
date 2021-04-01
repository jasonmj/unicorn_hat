defmodule UnicornHatTest do
  use ExUnit.Case
  doctest UnicornHat

  test "greets the world" do
    assert UnicornHat.hello() == :world
  end
end
