defmodule DeveloperPortalWeb.ErrorJSONTest do
  use DeveloperPortalWeb.ConnCase, async: true

  test "renders 404" do
    assert DeveloperPortalWeb.ErrorJSON.render("404.json", %{}) == %{
             errors: %{detail: "Not Found"}
           }
  end

  test "renders 500" do
    assert DeveloperPortalWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
