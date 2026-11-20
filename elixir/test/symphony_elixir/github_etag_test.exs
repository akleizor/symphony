defmodule SymphonyElixir.GitHubEtagTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.GitHub.Client, as: GitHubClient

  @settings %{kind: "github", provider: %{"repo" => "octo/repo", "token" => "t", "api_url" => "https://github.test"}}
  @issue %{"number" => 7, "title" => "Seven", "state" => "open", "html_url" => "https://github.test/octo/repo/issues/7"}

  setup do
    defaults = Req.default_options()
    on_exit(fn -> Req.default_options(defaults) end)
    :ok = GitHubClient.init_etag_cache()
    :ets.delete_all_objects(:symphony_github_etags)
    :ok
  end

  # Keep the client and Req real; replace only transport with a GitHub that answers 304 to a known ETag.
  test "an unchanged issue is served from the cache on GitHub's free 304" do
    owner = self()

    Req.default_options(
      plug: fn conn ->
        send(owner, {:if_none_match, Plug.Conn.get_req_header(conn, "if-none-match")})

        case Plug.Conn.get_req_header(conn, "if-none-match") do
          [~s("v1")] ->
            Plug.Conn.send_resp(conn, 304, "")

          [] ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.put_resp_header("etag", ~s("v1"))
            |> Plug.Conn.send_resp(200, Jason.encode!(@issue))
        end
      end
    )

    assert {:ok, [%{id: "7", title: "Seven"}]} = GitHubClient.fetch_issues_by_ids_for_test(["7"], @settings, &request/5)
    assert_received {:if_none_match, []}
    assert {:ok, [%{id: "7", title: "Seven"}]} = GitHubClient.fetch_issues_by_ids_for_test(["7"], @settings, &request/5)
    assert_received {:if_none_match, [~s("v1")]}
  end

  defp request(method, path, params, body, settings),
    do: GitHubClient.perform_request_for_test(method, path, params, body, settings)
end
