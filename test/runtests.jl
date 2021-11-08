using Test

# TODO: use a fixed version of Pluto, once 0.17.1 + x has been released
#       This is currently testing against Pluto#main
import Pkg
Pkg.add(url="https://github.com/fonsp/Pluto.jl", rev="main")

import Pluto
import Pluto: PlutoRunner, Notebook, WorkspaceManager, Cell, ServerSession, ClientSession, update_run!

include("./helpers.jl")

🍭 = ServerSession()
🍭.options.evaluation.workspace_use_distributed = false

fakeclient = ClientSession(:fake, nothing)
🍭.connected_clients[fakeclient.id] = fakeclient

@testset "Use ref" begin
    @testset "Implicit & explicit runs" begin
        notebook = Notebook(Cell.([
            "using PlutoHooks",
            "x = 1",
            """
            begin
                x;
                ref = @use_ref(1)

                ref[] += 1
            end
            """,
        ]))
        cell(idx) = notebook.cells[idx]

        update_run!(🍭, notebook, notebook.cells)

        @test cell(1) |> noerror
        @test cell(2) |> noerror
        @test cell(3) |> noerror
        @test cell(3).output.body == "2"

        update_run!(🍭, notebook, cell(2))

        @test cell(3).output.body == "3"

        for _ in 1:3
            update_run!(🍭, notebook, cell(2))
        end

        @test cell(3).output.body == "6"

        update_run!(🍭, notebook, cell(3))

        @test cell(3).output.body == "2"
    end
end

@testset "Use Effect" begin
    @testset "Implicit runs with dependencies" begin
        notebook = Notebook(Cell.([
            "using PlutoHooks",
            "x = 1",
            "y = 1",
            """
            begin
                y
                ref = @use_ref(1)
                @use_effect([x]) do
                    ref[] += 1
                end
                ref[]
            end
            """,
        ]))
        cell(idx) = notebook.cells[idx]
        update_run!(🍭, notebook, notebook.cells)

        @test cell(4) |> noerror
        @test cell(4).output.body == "2"

        update_run!(🍭, notebook, cell(3))
        @test cell(4).output.body == "2"

        update_run!(🍭, notebook, cell(2)) # Not changing the value of x
        @test cell(4).output.body == "2"

        setcode(cell(2), "x = 2")
        update_run!(🍭, notebook, cell(2)) # Changing the value of x
        @test cell(4).output.body == "3"
    end

    @testset "Cleanups" begin
        notebook = Notebook(Cell.([
            "using PlutoHooks",
            "cleanup_ref = @use_ref(1)",
            "ref = @use_ref(1)",
            "x = 1",
            """
            begin
                @use_effect([x]) do
                    ref[] += 1
                    () -> (cleanup_ref[] += 1)
                end
            end
            """,
            "cleanup_ref[]",
        ]))
        cell(idx) = notebook.cells[idx]
        update_run!(🍭, notebook, notebook.cells)

        @test all(noerror, notebook.cells)
        @test cell(6).output.body == "1"

        update_run!(🍭, notebook, [cell(4), cell(6)])
        @test cell(6).output.body == "1"

        setcode(cell(4), "x = 2")
        update_run!(🍭, notebook, [cell(4), cell(6)])
        @test cell(6).output.body == "2"

        update_run!(🍭, notebook, [cell(5), cell(6)])
        @test cell(6).output.body == "3"
    end
end

@testset "Use state" begin
    @testset "Trigger reactive run" begin
        # Use state tests are distributed because the self run relaying is not closed for non-distributed notebooks
        🍭.options.evaluation.workspace_use_distributed = true
    
        notebook = Notebook(Cell.([
            "using PlutoHooks",
            "state, setstate = @use_state(1)",
            "trigger = false",
            """
            if trigger
                setstate(10)
            end
            """,
            "state",
        ]))
        cell(idx) = notebook.cells[idx]

        update_run!(🍭, notebook, notebook.cells)

        @test all(noerror, notebook.cells)
        @test notebook.cells[end].output.body == "1"

        setcode(cell(3), "trigger = true")
        update_run!(🍭, notebook, cell(3))

        sleep(.3) # Reactive run is async

        @test notebook.cells[end].output.body == "10"

        setcode(cell(3), "trigger = false")
        update_run!(🍭, notebook, cell(3))
        update_run!(🍭, notebook, cell(2))
        
        @test notebook.cells[end].output.body == "1"

        WorkspaceManager.unmake_workspace((🍭, notebook))
        🍭.options.evaluation.workspace_use_distributed = false
    end
end

@testset "Use deps" begin
    notebook = Notebook(Cell.([
        "using PlutoHooks",
        "x = 1",
        """
        @use_deps([x]) do
            ref = @use_ref(1)

            ref[] += 1
        end
        """,
    ]))
    cell(idx) = notebook.cells[idx]
    update_run!(🍭, notebook, notebook.cells)

    @test all(noerror, notebook.cells)
    @test cell(3).output.body == "2"

    update_run!(🍭, notebook, cell(2))
    @test cell(3).output.body == "3"

    setcode(cell(2), "x = 2")
    update_run!(🍭, notebook, cell(2))
    @test cell(3).output.body == "2"
end

@testset "use task" begin
    🍭.options.evaluation.workspace_use_distributed = true
    notebook = Notebook(Cell.([
        "using PlutoHooks",
        """
        begin
            state, setstate = @use_state(1)
            @use_task([]) do
                sleep(.1)
                setstate(2)
            end
        end
        """,
        "state"
    ]))
    update_run!(🍭, notebook, notebook.cells)

    @test notebook.cells[3] |> noerror
    @test notebook.cells[3].output.body == "1"

    sleep(.3)

    @test notebook.cells[3].output.body == "2"

    WorkspaceManager.unmake_workspace((🍭, notebook))
    🍭.options.evaluation.workspace_use_distributed = false
end