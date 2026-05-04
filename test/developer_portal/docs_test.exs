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
             "architecture"
           ]

    dashboard_sdk = Enum.find(version.sections, &(&1.id == "dashboard-sdk"))

    assert Enum.any?(dashboard_sdk.toc, &(&1.id == "quick-start"))

    assert Phoenix.HTML.Safe.to_iodata(dashboard_sdk.html) |> IO.iodata_to_binary() =~
             ~s(id="quick-start")

    assert Enum.any?(version.sections, &String.contains?(&1.body, "WebAssembly"))
  end
end
