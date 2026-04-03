defmodule DeveloperPortal.ApiDocs.Source do
  @moduledoc false

  @callback fetch_documents(keyword()) ::
              {:ok, %{optional(String.t()) => DeveloperPortal.ApiDocs.Document.t()}}
              | {:error, term()}
end
