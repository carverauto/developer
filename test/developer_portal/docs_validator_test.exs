defmodule DeveloperPortal.DocsValidatorTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.Docs

  test "rejects broken internal docs links" do
    temp_dir =
      Path.join(System.tmp_dir!(), "developer-portal-docs-#{System.unique_integer([:positive])}")

    version_dir = Path.join(temp_dir, "v1")
    on_exit(fn -> File.rm_rf(temp_dir) end)
    File.mkdir_p!(version_dir)

    File.write!(Path.join(temp_dir, "versions.yaml"), """
    - id: v1
      label: V1
      title: Test Docs
      summary: Test docs summary
    """)

    File.write!(Path.join(version_dir, "getting-started.md"), """
    ---
    title: Getting Started
    audience: All developers
    description: Intro
    order: 10
    ---

    Read the [missing guide](/docs/v1/does-not-exist).
    """)

    assert_raise ArgumentError, ~r/broken docs link/, fn ->
      Docs.load(
        Path.join(temp_dir, "versions.yaml"),
        Path.wildcard(Path.join(version_dir, "*.md"))
      )
    end
  end

  test "accepts valid docs routes and relative section links" do
    temp_dir =
      Path.join(System.tmp_dir!(), "developer-portal-docs-#{System.unique_integer([:positive])}")

    version_dir = Path.join(temp_dir, "v1")
    on_exit(fn -> File.rm_rf(temp_dir) end)
    File.mkdir_p!(version_dir)

    File.write!(Path.join(temp_dir, "versions.yaml"), """
    - id: v1
      label: V1
      title: Test Docs
      summary: Test docs summary
    """)

    File.write!(Path.join(version_dir, "getting-started.md"), """
    ---
    title: Getting Started
    audience: All developers
    description: Intro
    order: 10
    ---

    Continue with the [Go SDK](go-sdk) guide and the [plugins page](/plugins).
    """)

    File.write!(Path.join(version_dir, "go-sdk.md"), """
    ---
    title: Go SDK
    audience: Go
    description: Go docs
    order: 20
    ---

    Back to [getting started](/docs/v1/getting-started).
    """)

    versions =
      Docs.load(
        Path.join(temp_dir, "versions.yaml"),
        Path.wildcard(Path.join(version_dir, "*.md"))
      )

    assert [%{id: "v1", sections: [%{id: "getting-started"}, %{id: "go-sdk"}]}] = versions
  end
end
