defmodule DeveloperPortal.Docs.Version do
  @moduledoc "A documentation version with associated sections."

  @enforce_keys [:id, :label, :title, :summary, :sections]
  defstruct [:id, :label, :title, :summary, :sections]
end
