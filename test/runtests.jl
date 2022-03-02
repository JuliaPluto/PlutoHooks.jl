using Test

using PlutoHooks

include("./helpers.jl")

#=
We run the tests without Pluto twice:
  1. Without Main.PlutoRunner defined (No Pluto in sight)
  2. With Main.PlutoRunner defined (Pluto is defined but the macro is not run in Pluto)
=#

include("./without_pluto.jl")
include("./with_pluto.jl")
include("./without_pluto.jl")
