### A Pluto.jl notebook ###
# v0.17.0

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
using PlutoUI, PlutoTest # TODO: Make dependencies only for development

# ╔═╡ 49cb409b-e564-47aa-9dae-9bc5bffa991d
using UUIDs

# ╔═╡ f751bfc3-0273-4ac1-9140-b6f8a16c0794
using HypertextLiteral

# ╔═╡ b0350bd0-5dd2-4c73-b301-f076123144c2
using FileWatching

# ╔═╡ 729ae3bb-79c2-4fcd-8645-7e0071365537
md"""
# PlutoHooks.jl

Let's implement some [React.js](https://reactjs.org/) features in [Pluto.jl](https://plutojl.org) using the function wrapped macros. Note that function wrapping does not work for all instructions. The details can be seen in [`ExpressionExplorer.jl`](https://github.com/fonsp/Pluto.jl/blob/9b4b4f3f47cd95d2529229296f9b3007ed1e2163/src/analysis/ExpressionExplorer.jl#L1222-L1240). Use the Pluto version in [Pluto.jl#1597](https://github.com/fonsp/Pluto.jl/pull/1597) to try it out.
"""

# ╔═╡ c82c8aa9-46a9-4110-88af-8638625222e3
"""
Embeds a reference in the AST. This can be used to associate state to a function wapped cell.
"""
macro use_ref(init=nothing)
	ref = Ref{Any}()
	initialized = Ref{Bool}(false)
	quote
		if !$initialized[]
			$ref[] = $init
			$initialized[] = true
		end
		$ref
	end
end

# ╔═╡ 1df0a586-3692-11ec-0171-0b48a4a1c4bd
"""
Returns a `Tuple{Ref{Any},Function}` where the `Ref` contains the last value of the state and the `Function` can be used to set the state value.

```julia
# in one cell
state, set_state = @use_state(1.2)

# later
set_state(3.0)

# in yet another cell
x = state[]
```
"""
macro use_state(init=nothing, cell_id=nothing)
	cell_id = cell_id !== nothing ? cell_id : PlutoRunner.parse_cell_id(string(__source__.file))

	quote
		state_ref = @use_ref($(esc(init)))
		set_state = (new) -> begin
			state_ref[] = new
			PlutoRunner._self_run($cell_id)
			@info "called use_state" cell_id=$cell_id
		end
		(state_ref[], set_state)
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
	pl, set_plot = @use_state()
	value, set_value = @use_state(1.)

	pl
end

# ╔═╡ 3c40962c-ac21-411d-aeec-1d456f10e814
begin
	# set_value(1.2 * value[])
	
	# set_plot((x -> sin(value[] * x)).(1:10))
end;

# ╔═╡ c23ad7e6-6bb0-4900-998e-7102316fb0ec
md"""
### `@use_effect` playground
"""

# ╔═╡ 432135f3-431f-43ed-b80e-63bda8096ffe
@bind use_effect Button("Click to try @use_effect")

# ╔═╡ 82ddd527-f6a2-4359-a36e-238b2543330d
@bind x Slider(1:10, show_value=true)

# ╔═╡ cadf9ac8-4caa-4bf4-bebe-f911b949f490
begin
	struct Server
		x
		function Server(x)
			@info "server instanciation $x"
			new(x)
		end
	end
	start(s::Server) = @info "starting server $(s.x)"
	stop(s::Server) = @info "stopping server $(s.x)"
end

# ╔═╡ bc0e4219-a40b-46f5-adb2-f164d8a9bbdb
"""
Does the computation only at init time.
"""
macro use_memo(f)
	quote
		ref = @use_ref($f())
		ref[]
	end
end

# ╔═╡ 780dfe21-a12c-48d4-977b-df83257e201e
@bind do_compute Button()

# ╔═╡ 5ee52f3d-5f4f-40c3-a0e1-ede73fcdeb28
begin
	do_compute;
	with_terminal() do
		@time @use_memo(() -> begin
			sleep(1.)
			return :very_long_compute
		end)
	end
end

# ╔═╡ 274c2be6-6075-45cf-b28a-862c8bf64bd4
md"""
### Util functions
---
"""

# ╔═╡ 51371f3c-472e-4002-bae4-c20b8364af32
"""
Turns different way of expressing code to an anonymous arrow function definition.
"""
function as_arrow(ex::Expr)
	if Meta.isexpr(ex, :(->))
		ex
	elseif Meta.isexpr(ex, :do)
		Expr(:(->), ex.args...)
	elseif Meta.isexpr(ex, :block)
		Expr(:(->), Expr(:tuple), ex)
	elseif Meta.isexpr(ex, :function)
		root = ex.args[1]
		Expr(:(->), root.head == :call ? Expr(:tuple, root.args[2:end]...) : root, ex.args[2])
	else
		throw("Can't transform expression into an arrow function")
	end
end

# ╔═╡ 89b3f807-2e24-4454-8f4c-b2a98aee571e
"""
Used to run a side effect only when the cell is run for the first time. This is missing the React.js functionality of specifying dependencies.

```julia
@use_effect([x, y]) do
	x + y
end
```
"""
macro use_effect(f, dependencies=:([]), cell_id=nothing)
	dependencies_prev_values = [nothing for _ in 1:length(dependencies.args)]
	cell_id = cell_id !== nothing ? cell_id : PlutoRunner.parse_cell_id(string(__source__.file))
	dependencies = esc(dependencies)

	quote
		done = @use_ref(false)
		cleanup = @use_ref(() -> nothing)
		dependencies_prev_values = @use_ref($dependencies_prev_values)

		PlutoRunner.register_cleanup($cell_id) do
			cleanup[]()
		end

		if !done[] || $dependencies != dependencies_prev_values[]
			done[] = true
			dependencies_prev_values[] = copy($dependencies)
			cleanup[]()

	
			local cleanup_func = $(esc(as_arrow(f)))()
			if cleanup_func isa Function
				cleanup[] = cleanup_func
			end
		end

		nothing
	end
end

# ╔═╡ 3d0683d4-8da0-48e1-94d4-bce3d23f8313
begin
	use_effect
	server = Server(x)

	@use_effect([x]) do
		start(server)

		() -> begin
			stop(server)
		end
	end

end

# ╔═╡ 6f38af33-9cae-4e2b-8431-8ea3185e109a
as_arrow(:(function(x, y) x+y end))

# ╔═╡ 15498bfa-a8f3-4e7d-aa2e-4daf00be1ef5
as_arrow(:(function f(x, y) x+y end))

# ╔═╡ b889049a-ab95-454d-8297-b484ea52f4f5
as_arrow(:(function f() x+y end))

# ╔═╡ fe191402-fdcf-4e3e-993e-43991576f33b
macro current_cell_id()
	PlutoRunner.parse_cell_id(string(__source__.file))
end

# ╔═╡ 80ed971f-59ba-42ab-ad61-e18026ee68d4
# let
# 	x = @use_ref(2)
# 	if x[] == 2
# 		@current_cell_id() |> PlutoRunner._self_run
# 	end
# 	x[] += 1
# 	sleep(.8)
	
# 	x[]
# end

# ╔═╡ 6b49426b-12f5-4458-8e6e-c6f0c0365b4b
struct Progress
	p::Float64
end

# ╔═╡ 060fe8be-0ace-4ce5-8485-53cb74fe8319
function Base.show(io::IO, m::MIME"text/html", p::Progress)
	content = @htl("""
		<span>$(floor(p.p*100))%</span>
	""")
	show(io, m, content)
end

# ╔═╡ 92c58503-96fc-43dc-b051-40bff55eb142
@bind n_iter Slider(1:20, default=10, show_value=true)

# ╔═╡ 1c1601e0-e23e-4bad-8dd1-bbfa32f89fb2
begin
	y, sety = @use_state(Progress(0.))
	set_progress = (x) -> sety(Progress(x))

	@use_effect([n_iter]) do
		task = Task() do
			for i in 1:n_iter
				sleep(1.)
				set_progress(i/n_iter)
			end
		end |> schedule

		() -> begin
			if !istaskdone(task) && !istaskfailed(task)
				Base.schedule(task, InterruptException(), error=true)
			end
		end
	end
end

# ╔═╡ be32d617-b1c8-4945-8e8e-910c84cc7218
y

# ╔═╡ e6860783-0c6c-4095-8b9b-e0f506f32fc1
# begin
# 	file_content, set_file_content = @use_state("")

# 	@use_effect([filename]) do
# 		task = Task() do
# 			@info "restarting" filename
# 			read(filename, String) |> set_file_content

# 			try
# 				while true
# 					watch_file(filename)
# 					@info "update"
# 					set_file_content(read(filename, String))
# 				end
# 			catch e
# 				@error "filewatching failed" err=e
# 				throw(e)
# 			end
# 		end |> schedule

# 		() -> begin
# 			if !istaskdone(task) && !istaskfailed(task)
# 				Base.schedule(task, InterruptException(), error=true)
# 			elseif istaskfailed(task)
# 				@warn "task is failed" res=fetch(task)
# 			end
# 		end
# 	end

# 	file_content |> Text
# end

# ╔═╡ 0b60be66-b671-41aa-9b18-b43f43420aaf
macro caller_cell_id()
	esc(quote
        PlutoRunner.parse_cell_id(string(__source__.file::Symbol))
    end)
end

# ╔═╡ 9ec99592-955a-41bd-935a-b34f37bb5977
"""
Wraps a `Task` with the current cell. When the cell state is reset, sends an `InterruptException` to the underlying `Task`.

```julia
@pluto_async begin
	while true
		sleep(2.)
		@info "this is updating"
	end
end
```

It can be combined with `@use_state` for background updating of values.
"""
macro pluto_async(f, cell_id=nothing)
	cell_id = cell_id !== nothing ? cell_id : @caller_cell_id()

	quote
		@use_effect([], $cell_id) do
			task = Task() do
				try
					$(esc(as_arrow(f)))()
				catch e
					e isa InterruptException && return
					@error "task failed" err=e
				end
			end |> schedule
	
			() -> begin
				if !istaskdone(task) && !istaskfailed(task)
					Base.schedule(task, InterruptException(), error=true)
				elseif istaskfailed(task)
					res = fetch(task)
					res isa InterruptException && return
					@warn "task is failed" res
				end
			end
		end
	end
end

# ╔═╡ 10f015c0-84b1-43b6-b2c1-83819740af44
# @pluto_async begin
# 	while true 
# 		sleep(2.)
# 		@info "heyeyeyry"
# 	end
# end

# ╔═╡ 461231e8-4958-46b9-88cb-538f9151a4b0
macro file_watching(filename)
	cell_id = @caller_cell_id()
	filename = esc(filename)

	quote
		file_content, set_file_content = @use_state(read($filename, String), $cell_id)

		@pluto_async($cell_id) do
			while true
				watch_file($filename)
				set_file_content(read($filename, String))
			end
		end
	
		file_content
	end
end

# ╔═╡ dfa5f319-7948-47a4-85a6-e6e24b749b29
filename = "/home/paul/Projects/myfile.csv"

# ╔═╡ 0bce9856-6916-4d54-9534-aaddcd8126bc
(@file_watching(filename) |> Text), @current_cell_id()

# ╔═╡ 480dd46c-cc31-46b5-bc2d-2e1680d5c682
function ingredients(path::String)
	# this is from the Julia source code (evalfile in base/loading.jl)
	# but with the modification that it returns the module instead of the last object
	name = Symbol(basename(path))
	m = Module(name)
	Core.eval(m,
        Expr(:toplevel,
             :(eval(x) = $(Expr(:core, :eval))($name, x)),
             :(include(x) = $(Expr(:top, :include))($name, x)),
             :(include(mapexpr::Function, x) = $(Expr(:top, :include))(mapexpr, $name, x)),
             :(include($path))))
	m
end

# ╔═╡ d84f47ba-7c18-4d6c-952c-c9a5748a51f8
macro ingredients(filename)
	cell_id = @caller_cell_id()
	filename = esc(filename)

	quote
		mod, set_mod = @use_state(ingredients($filename), $cell_id)

		@pluto_async($cell_id) do
			while true
				watch_file($filename)
				set_mod(ingredients($filename))
			end
		end

		mod
	end
end

# ╔═╡ ff764d7d-2c07-44bd-a675-89c9e2b00151
notebook = @ingredients("/home/paul/Projects/cookie.jl")

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
FileWatching = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
PlutoTest = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
UUIDs = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[compat]
HypertextLiteral = "~0.9.2"
PlutoTest = "~0.1.2"
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

[[FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

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

[[PlutoTest]]
deps = ["HypertextLiteral", "InteractiveUtils", "Markdown", "Test"]
git-tree-sha1 = "b7da10d62c1ffebd37d4af8d93ee0003e9248452"
uuid = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
version = "0.1.2"

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
# ╠═c82c8aa9-46a9-4110-88af-8638625222e3
# ╠═1df0a586-3692-11ec-0171-0b48a4a1c4bd
# ╟─4960d74a-6792-4e17-8fa2-a7f0cfa604d6
# ╟─d9b59671-848b-4f82-89bf-6fc51773cf3e
# ╟─7cdd6ad5-d2e5-4a0d-80e3-810a8d475d0f
# ╠═e473af39-d4f1-4a90-a6c2-15ec17bee632
# ╠═3c40962c-ac21-411d-aeec-1d456f10e814
# ╠═89b3f807-2e24-4454-8f4c-b2a98aee571e
# ╟─c23ad7e6-6bb0-4900-998e-7102316fb0ec
# ╟─432135f3-431f-43ed-b80e-63bda8096ffe
# ╟─82ddd527-f6a2-4359-a36e-238b2543330d
# ╠═cadf9ac8-4caa-4bf4-bebe-f911b949f490
# ╠═3d0683d4-8da0-48e1-94d4-bce3d23f8313
# ╠═bc0e4219-a40b-46f5-adb2-f164d8a9bbdb
# ╟─780dfe21-a12c-48d4-977b-df83257e201e
# ╠═5ee52f3d-5f4f-40c3-a0e1-ede73fcdeb28
# ╟─274c2be6-6075-45cf-b28a-862c8bf64bd4
# ╠═6d25c787-2b82-4d7f-8b10-d92c0ba8bc01
# ╠═49cb409b-e564-47aa-9dae-9bc5bffa991d
# ╠═51371f3c-472e-4002-bae4-c20b8364af32
# ╠═6f38af33-9cae-4e2b-8431-8ea3185e109a
# ╠═15498bfa-a8f3-4e7d-aa2e-4daf00be1ef5
# ╠═b889049a-ab95-454d-8297-b484ea52f4f5
# ╠═fe191402-fdcf-4e3e-993e-43991576f33b
# ╠═80ed971f-59ba-42ab-ad61-e18026ee68d4
# ╠═6b49426b-12f5-4458-8e6e-c6f0c0365b4b
# ╠═060fe8be-0ace-4ce5-8485-53cb74fe8319
# ╠═f751bfc3-0273-4ac1-9140-b6f8a16c0794
# ╟─92c58503-96fc-43dc-b051-40bff55eb142
# ╠═1c1601e0-e23e-4bad-8dd1-bbfa32f89fb2
# ╠═be32d617-b1c8-4945-8e8e-910c84cc7218
# ╠═b0350bd0-5dd2-4c73-b301-f076123144c2
# ╠═e6860783-0c6c-4095-8b9b-e0f506f32fc1
# ╠═0b60be66-b671-41aa-9b18-b43f43420aaf
# ╠═9ec99592-955a-41bd-935a-b34f37bb5977
# ╠═10f015c0-84b1-43b6-b2c1-83819740af44
# ╠═461231e8-4958-46b9-88cb-538f9151a4b0
# ╟─dfa5f319-7948-47a4-85a6-e6e24b749b29
# ╠═0bce9856-6916-4d54-9534-aaddcd8126bc
# ╠═480dd46c-cc31-46b5-bc2d-2e1680d5c682
# ╠═d84f47ba-7c18-4d6c-952c-c9a5748a51f8
# ╠═ff764d7d-2c07-44bd-a675-89c9e2b00151
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
