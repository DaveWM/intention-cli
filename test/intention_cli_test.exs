defmodule IntentionCliTest do
  use ExUnit.Case
  doctest IntentionCli

  test "greets the world" do
    assert IntentionCli.hello() == :world
  end
end
