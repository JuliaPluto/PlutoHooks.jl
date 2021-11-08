test_env = mktempdir()

function with_test_env()
    hooks_path = joinpath(@__DIR__, "..") |> normpath

    """
    begin
        import Pkg
        Pkg.activate("$test_env")
        Pkg.develop(path="$hooks_path")
    end
    """
end

function noerror(cell)
    errored = cell.errored
    if errored
        @show cell.output
    end
    !errored
end

function setcode(cell, code)
    cell.code = code
end
