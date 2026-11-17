defmodule SymphonyElixir.WorkflowStoreTest do
  use SymphonyElixir.TestSupport

  defmodule ExitingStore do
    use GenServer

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call(_message, _from, _state), do: exit(:store_unavailable)
  end

  test "settings reads the workflow file when the store call exits" do
    original_workflow_path = Workflow.workflow_file_path()
    workflow_store_pid = Process.whereis(WorkflowStore)

    on_exit(fn ->
      Workflow.set_workflow_file_path(original_workflow_path)

      if is_pid(workflow_store_pid) and is_nil(Process.whereis(WorkflowStore)) do
        Supervisor.restart_child(SymphonyElixir.Supervisor, WorkflowStore)
      end
    end)

    write_workflow_file!(Workflow.workflow_file_path(), poll_interval_ms: 45_000)

    assert :ok = Supervisor.terminate_child(SymphonyElixir.Supervisor, WorkflowStore)
    assert {:ok, _pid} = GenServer.start(ExitingStore, :ok, name: WorkflowStore)

    assert {:ok, settings} = WorkflowStore.settings()
    assert settings.polling.interval_ms == 45_000
  end
end