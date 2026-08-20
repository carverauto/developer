defmodule DeveloperPortal.Docs do
  @moduledoc """
  Repository-backed documentation metadata loaded from markdown and YAML files.
  """

  alias DeveloperPortal.Docs.Section
  alias DeveloperPortal.Docs.Validator
  alias DeveloperPortal.Docs.Version

  @content_root Path.expand("../../priv/content/docs", __DIR__)
  @versions_path Path.join(@content_root, "versions.yaml")
  @section_paths Path.wildcard(Path.join(@content_root, "*/*.md"))

  for path <- [@versions_path | @section_paths] do
    @external_resource path
  end

  def versions do
    Enum.map(all(), &Map.take(&1, [:id, :label]))
  end

  def version(id) do
    Enum.find(all(), &(&1.id == id))
  end

  def section(version_id, section_id) do
    with %{sections: sections} <- version(version_id) do
      Enum.find(sections, &(&1.id == section_id))
    end
  end

  def all do
    content_root = Path.join(:code.priv_dir(:developer_portal), "content/docs")

    load(
      Path.join(content_root, "versions.yaml"),
      Path.wildcard(Path.join(content_root, "*/*.md"))
    )
  end

  def load(versions_path, section_paths) do
    versions =
      versions_path
      |> YamlElixir.read_from_file!()
      |> Enum.map(fn attrs ->
        attrs
        |> normalize_map_keys()
        |> then(fn version ->
          %Version{
            id: fetch_string!(version, "id"),
            label: fetch_string!(version, "label"),
            title: fetch_string!(version, "title"),
            summary: fetch_string!(version, "summary"),
            sections: []
          }
        end)
      end)

    sections_by_version =
      section_paths
      |> Enum.map(&build_section/1)
      |> Enum.group_by(& &1.version)

    Enum.map(versions, fn version ->
      %{
        version
        | sections: Map.get(sections_by_version, version.id, []) |> Enum.sort_by(& &1.order)
      }
    end)
    |> Validator.validate!()
  end

  defp build_section(path) do
    version = path |> Path.dirname() |> Path.basename()
    id = path |> Path.basename(".md")

    {frontmatter, body} = parse_markdown_file!(path)
    attrs = normalize_map_keys(frontmatter)

    toc = markdown_toc(body)

    %Section{
      id: id,
      version: version,
      title: fetch_string!(attrs, "title"),
      audience: fetch_string!(attrs, "audience"),
      description: fetch_string!(attrs, "description"),
      order: fetch_integer!(attrs, "order"),
      body: body,
      html: markdown_to_html(body, toc),
      toc: toc
    }
  end

  defp parse_markdown_file!(path) do
    case File.read!(path) do
      <<"---\n", rest::binary>> ->
        [frontmatter, body] = String.split(rest, "\n---\n", parts: 2)
        {YamlElixir.read_from_string!(frontmatter), String.trim(body)}

      _ ->
        raise ArgumentError, "expected markdown file with YAML front matter: #{path}"
    end
  end

  defp markdown_to_html(markdown, toc) do
    markdown
    |> MDEx.to_html!(
      extension: [
        strikethrough: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true
      ]
    )
    |> render_code_windows()
    |> add_heading_ids(toc)
    |> Phoenix.HTML.raw()
  end

  defp render_code_windows(html) do
    ensure_code_highlighters_started()

    Regex.replace(
      ~r/<pre><code(?: class="([^"]*)")?>(.*?)<\/code><\/pre>/s,
      html,
      fn _full_block, class, escaped_code ->
        language = normalize_code_language(class)
        highlighted_code = highlight_code(escaped_code, language)
        label = code_language_label(language)

        ~s(<div class="not-prose docs-code-window mockup-code" data-language="#{label}"><pre><code class="makeup language-#{language}">#{highlighted_code}</code></pre></div>)
      end
    )
  end

  defp highlight_code(escaped_code, language) do
    with {:ok, {lexer, lexer_opts}} <-
           Makeup.Registry.fetch_lexer_by_name(makeup_language(language)) do
      escaped_code
      |> unescape_html()
      |> IO.iodata_to_binary()
      |> Makeup.highlight_inner_html(
        lexer: lexer,
        lexer_options: lexer_opts,
        formatter_options: [highlight_tag: "span"]
      )
    else
      :error -> escaped_code
    end
  end

  defp ensure_code_highlighters_started do
    Application.ensure_all_started(:makeup_elixir)
    Application.ensure_all_started(:makeup_json)
    Application.ensure_all_started(:makeup_ts)
  end

  defp normalize_code_language(class) when class in [nil, ""], do: "text"

  defp normalize_code_language(class) do
    class
    |> String.split()
    |> List.first()
    |> String.replace_prefix("language-", "")
    |> String.downcase()
    |> then(fn
      language when language in ["jsx", "javascript"] -> "js"
      language when language in ["tsx", "typescript"] -> "ts"
      language when language in ["json"] -> "json"
      language when language in ["iex", "elixir"] -> "elixir"
      language when language in ["sh", "shell", "zsh"] -> "bash"
      language when language in ["txt", "plaintext", "plain"] -> "text"
      language -> String.replace(language, ~r/[^a-z0-9_-]/, "")
    end)
    |> case do
      "" -> "text"
      language -> language
    end
  end

  defp makeup_language(language) when language in ["js", "ts"], do: language
  defp makeup_language(language), do: language

  defp code_language_label("js"), do: "JSX"
  defp code_language_label("ts"), do: "TypeScript"
  defp code_language_label("json"), do: "JSON"
  defp code_language_label("elixir"), do: "Elixir"
  defp code_language_label("bash"), do: "Shell"
  defp code_language_label("go"), do: "Go"
  defp code_language_label("text"), do: "Text"
  defp code_language_label(language), do: String.upcase(language)

  entities = [{"&amp;", ?&}, {"&lt;", ?<}, {"&gt;", ?>}, {"&quot;", ?"}, {"&#39;", ?'}]

  for {encoded, decoded} <- entities do
    defp unescape_html(unquote(encoded) <> rest), do: [unquote(decoded) | unescape_html(rest)]
  end

  defp unescape_html(<<c, rest::binary>>), do: [c | unescape_html(rest)]
  defp unescape_html(<<>>), do: []

  defp markdown_toc(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.reduce({[], false}, fn line, {entries, in_code_block?} ->
      cond do
        String.starts_with?(line, "```") ->
          {entries, not in_code_block?}

        in_code_block? ->
          {entries, in_code_block?}

        match = Regex.run(~r/^([#]{2,3})\s+(.+)$/, line) ->
          [_, marks, title] = match
          title = clean_heading(title)
          id = heading_id(title, entries)

          {
            entries ++ [%{id: id, level: String.length(marks), title: title}],
            in_code_block?
          }

        true ->
          {entries, in_code_block?}
      end
    end)
    |> elem(0)
  end

  defp add_heading_ids(html, toc) do
    Enum.reduce(toc, html, fn %{id: id, level: level}, acc ->
      Regex.replace(
        ~r/<h#{level}>/,
        acc,
        ~s(<h#{level} id="#{id}" class="scroll-mt-24">),
        global: false
      )
    end)
  end

  defp clean_heading(title) do
    title
    |> String.trim()
    |> String.replace(~r/`([^`]+)`/, "\\1")
    |> String.replace(~r/\[([^\]]+)\]\([^)]+\)/, "\\1")
  end

  defp heading_id(title, existing_entries) do
    base =
      title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    same_base_count =
      Enum.count(existing_entries, fn %{id: id} ->
        id == base or String.starts_with?(id, "#{base}-")
      end)

    if same_base_count == 0 do
      base
    else
      "#{base}-#{same_base_count + 1}"
    end
  end

  defp normalize_map_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp fetch_string!(attrs, key) do
    attrs
    |> Map.fetch!(key)
    |> to_string()
  end

  defp fetch_integer!(attrs, key) do
    attrs
    |> Map.fetch!(key)
    |> then(fn
      value when is_integer(value) -> value
      value when is_binary(value) -> String.to_integer(value)
    end)
  end
end
