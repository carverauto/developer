defmodule DeveloperPortal.DocsTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.Docs

  test "loads versions from repository-backed yaml" do
    assert [%{id: "v2", label: "V2"}] = Docs.versions()
  end

  test "loads docs sections from markdown files" do
    version = Docs.version("v2")

    assert version.title == "ServiceRadar V2 documentation"

    assert Enum.map(version.sections, & &1.id) == [
             "getting-started",
             "go-sdk",
             "rust-sdk",
             "dashboard-sdk",
             "dashboard-templates",
             "signal-display-contracts",
             "architecture"
           ]

    assert Enum.any?(version.sections, &String.contains?(&1.body, "WebAssembly"))
  end
end
