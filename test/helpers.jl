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