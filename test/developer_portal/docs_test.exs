defmodule DeveloperPortal.DocsTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.Docs

  test "loads versions from repository-backed yaml" do
    assert [%{id: "v1", label: "V1"}] = Docs.versions()
  end

  test "loads docs sections from markdown files" do
    version = Docs.version("v1")

    assert version.title == "ServiceRadar V1 developer documentation"

    assert Enum.map(version.sections, & &1.id) == [
             "getting-started",
             "go-sdk",
             "rust-sdk",
             "architecture"
           ]

    assert Enum.any?(version.sections, &String.contains?(&1.body, "WebAssembly"))
  end
end
