defmodule DeveloperPortal.Repo do
  use Ecto.Repo,
    otp_app: :developer_portal,
    adapter: Ecto.Adapters.Postgres
end
