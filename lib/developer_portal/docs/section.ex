defmodule DeveloperPortal.Docs.Section do
  @moduledoc "A documentation section loaded from repository-backed markdown content."

  @enforce_keys [:id, :version, :title, :audience, :description, :order, :body, :html, :toc]
  defstruct [:id, :version, :title, :audience, :description, :order, :body, :html, :toc]
end
