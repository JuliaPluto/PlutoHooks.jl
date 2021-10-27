### A Pluto.jl notebook ###
# v0.16.2

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 6d25c787-2b82-4d7f-8b10-d92c0ba8bc01
using PlutoUI

# ╔═╡ 729ae3bb-79c2-4fcd-8645-7e0071365537
md"""
# PlutoHooks.jl

Let's implement some [React.js](https://reactjs.org/) features in [Pluto.jl](https://plutojl.org) using the function wrapped macros. Note that function wrapping does not work for all instructions. The details can be seen in [`ExpressionExplorer.jl`](https://github.com/fonsp/Pluto.jl/blob/9b4b4f3f47cd95d2529229296f9b3007ed1e2163/src/analysis/ExpressionExplorer.jl#L1222-L1240). Use the Pluto version in [Pluto.jl#1597](https://github.com/fonsp/Pluto.jl/pull/1597) to try it out.


"""

# ╔═╡ 1df0a586-3692-11ec-0171-0b48a4a1c4bd
"""
Returns a `Tuple{Ref{Any},Function}` where the `Ref` contains the last value of the state and the `Function` can be used to set the state value.

```julia
# in one cell
state, set_state = @useState(1.2)

# in another cell
set_state(3.0)

# in yet another cell
x = state[]
```
"""
macro useState(init=nothing)
	initialized = Ref{Bool}(false)
	state_ref = Ref{Any}(nothing)

	quote
		set_state = (new) -> ($state_ref[] = new)
		if !$initialized[]
			set_state($init)
			$initialized[] = true
			
		end
		($state_ref, set_state)
	end
end

# ╔═╡ 4960d74a-6792-4e17-8fa2-a7f0cfa604d6
@bind updater Button()

# ╔═╡ d9b59671-848b-4f82-89bf-6fc51773cf3e
@bind clock Clock()

# ╔═╡ 7cdd6ad5-d2e5-4a0d-80e3-810a8d475d0f
@bind button Button()

# ╔═╡ e473af39-d4f1-4a90-a6c2-15ec17bee632
begin
	clock; button;
	pl, set_plot = @useState()
	value, set_value = @useState(1.)

	pl[]
end

# ╔═╡ 92071f7f-74e2-4c29-9c8d-4d9849a861ed
parse_description(ex) = Ref(Dict())

# ╔═╡ 3c40962c-ac21-411d-aeec-1d456f10e814
begin
	set_value(1.2 * value[])
	
	set_plot((x -> sin(value[] * x)).(1:10))
end;

# ╔═╡ 89b3f807-2e24-4454-8f4c-b2a98aee571e
"""
Used to run a side effect only when the cell is run for the first time. This is missing the React.js functionality of specifying dependencies.

```julia
@useEffect([x, y]) do
	x + y
end
```
"""
macro useEffect(f, dependencies=:([]))
	dependencies_prev_values = Ref{Vector{Any}}([nothing for _ in 1:length(dependencies.args)])

	quote
		done, setdone = @useState(false)
		if !done[] || $dependencies != $dependencies_prev_values[]
			done[] = true
			$dependencies_prev_values[] = $dependencies
			$f()
		end
	end
end

# ╔═╡ 432135f3-431f-43ed-b80e-63bda8096ffe
@bind use_effect Button("Click to try @useEffect")

# ╔═╡ 82ddd527-f6a2-4359-a36e-238b2543330d
x = 10

# ╔═╡ 3d0683d4-8da0-48e1-94d4-bce3d23f8313
use_effect; @useEffect([x]) do 
	value[]
end

# ╔═╡ bc0e4219-a40b-46f5-adb2-f164d8a9bbdb
"""
Does the computation only at init time.
"""
macro useMemo(f)
	quote
		ref, _ = @useState($f())
		ref[]
	end
end

# ╔═╡ 780dfe21-a12c-48d4-977b-df83257e201e
@bind do_compute Button()

# ╔═╡ 5ee52f3d-5f4f-40c3-a0e1-ede73fcdeb28
begin
	do_compute;
	with_terminal() do
		@time @useMemo(() -> begin
			sleep(1.)
			return :very_long_compute
		end)
	end
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
PlutoUI = "~0.7.16"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[HypertextLiteral]]
git-tree-sha1 = "5efcf53d798efede8fee5b2c8b09284be359bf24"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.2"

[[IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "f19e978f81eca5fd7620650d7dbea58f825802ee"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.1.0"

[[PlutoUI]]
deps = ["Base64", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "4c8a7d080daca18545c56f1cac28710c362478f3"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.16"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
"""

# ╔═╡ Cell order:
# ╟─729ae3bb-79c2-4fcd-8645-7e0071365537
# ╠═6d25c787-2b82-4d7f-8b10-d92c0ba8bc01
# ╠═1df0a586-3692-11ec-0171-0b48a4a1c4bd
# ╟─4960d74a-6792-4e17-8fa2-a7f0cfa604d6
# ╟─d9b59671-848b-4f82-89bf-6fc51773cf3e
# ╟─7cdd6ad5-d2e5-4a0d-80e3-810a8d475d0f
# ╠═e473af39-d4f1-4a90-a6c2-15ec17bee632
# ╠═92071f7f-74e2-4c29-9c8d-4d9849a861ed
# ╠═3c40962c-ac21-411d-aeec-1d456f10e814
# ╠═89b3f807-2e24-4454-8f4c-b2a98aee571e
# ╟─432135f3-431f-43ed-b80e-63bda8096ffe
# ╠═82ddd527-f6a2-4359-a36e-238b2543330d
# ╠═3d0683d4-8da0-48e1-94d4-bce3d23f8313
# ╠═bc0e4219-a40b-46f5-adb2-f164d8a9bbdb
# ╟─780dfe21-a12c-48d4-977b-df83257e201e
# ╠═5ee52f3d-5f4f-40c3-a0e1-ede73fcdeb28
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
