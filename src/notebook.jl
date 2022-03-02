### A Pluto.jl notebook ###
# v0.18.1

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 49cb409b-e564-47aa-9dae-9bc5bffa991d
using UUIDs

# ╔═╡ 729ae3bb-79c2-4fcd-8645-7e0071365537
md"""
# PlutoHooks.jl

Bring your notebook to life! This is an abstraction based on [React.js Hooks](https://reactjs.org/docs/hooks-intro.html) to implement "react-like" features in [Pluto.jl](https://plutojl.org). It allows cells to carry information and processes between updates, and even update itself.

There is a lot you can do with this, but some examples:
- Run a process and relay it's output to the rest of your notebook.
- Watch a file and reload the content when it changes.
- Do a computation on separate thread while the rest of notebook continue running.

You need to use Pluto version >= 0.17.2.
"""

# ╔═╡ bc0e4219-a40b-46f5-adb2-f164d8a9bbdb
"""
	@use_memo(deps::Vector{Any}) do
		# Expensive computation/loading
	end

Does a computation only when the deps array has changed.
This is useful for heavy computations as well as resource fetches like file reading or fetching from the network.

```julia
# Only read a file once
@use_memo([filename]) do
	read(filename)
end
```

```julia
@use_memo([a, b]) do
	a + b # But they're like really big numbers
end
```
"""
macro use_memo(f, deps)
	quote
		ref = @use_ref(nothing)
		if @use_did_deps_change($(esc(deps)))
			ref[] = $(esc(f))()
		end
		ref[]
	end
end

# ╔═╡ 0f632b57-ea01-482b-b93e-d69f962a6d92
md"""
## Not really hooks but internally very hook-ish

These are all for making sure you have some level of Pluto-ness active. These are made to work outside of Pluto as well, but obviously give you the opposite results :P
"""

# ╔═╡ 8c2e9cad-eb63-4af5-8b52-629e8d3439bd
"""
	is_running_in_pluto_process()

This doesn't mean we're in a Pluto cell, e.g. can use @bind and hooks goodies.
It only means PlutoRunner is available (and at a version that technically supports hooks)
"""
function is_running_in_pluto_process()
	isdefined(Main, :PlutoRunner) &&
	# Also making sure my favorite goodies are present
	isdefined(Main.PlutoRunner, :GiveMeCellID) &&
	isdefined(Main.PlutoRunner, :GiveMeRerunCellFunction) &&
	isdefined(Main.PlutoRunner, :GiveMeRegisterCleanupFunction)
end

# ╔═╡ df0645b5-094a-45b9-b72a-ab7ef9901fa1
"""
	is_inside_pluto(mod::Module)

This can be useful to implement the behavior for when the hook is called outside Pluto but in the case where Pluto **can** be loaded.
"""
function is_inside_pluto(mod::Module)
	# Note: this could be moved to AbstractPlutoDingejtes
	startswith(string(nameof(mod)), "workspace#") &&
		isdefined(mod, Symbol("@bind"))
end

# ╔═╡ c82c8aa9-46a9-4110-88af-8638625222e3
"""
	@use_ref(initial_value::Any)::Ref{Any}

Creates a Ref that is stable over multiple **implicit** runs of the cell. Implicit run meaning a variable (or a bond) used in this cell is updated, causing this cell to re-run. When you press shift+enter in Pluto however, this ref will reset.

This is useful to keep state around between runs.
"""
macro use_ref(initial_value=nothing)
	if !is_inside_pluto(__module__)
        ref = Ref{Any}()
		return quote
            ref = $(ref)
            ref[] = $(esc(initial_value))
            ref
        end
	end

	ref_ref = Ref(Ref{Any}())

	quote
		# use_did_deps_change with empty array so it only refreshes
		# initially and on cell refresh.
		# You might wonder: But Michiel, this already refreshes on cell refresh,
		# 	because the macro will rerun!
		# I hear you. But I have bigger plans..... 😈
		if @use_did_deps_change([])
			$ref_ref[] = Ref{Any}($(esc(initial_value)))
		end
		$ref_ref[]
	end
end

# ╔═╡ 1df0a586-3692-11ec-0171-0b48a4a1c4bd
"""
	state, set_state = @use_state(initial_value::Any)

Returns a tuple for an update-able value. `state` will be whatever value you put in, and `set_state` is a function that you can call with a value, and it will set `state` to that value, and re-run the cell. Useful in combination with [`@use_effect`](@ref):

```julia
web_response = let
	state, set_state = @use_state(nothing)

	@use_effect([]) do
		schedule(Task() do
			response = HTTP.fetch("idk-what-api-HTTP.jl-has")
			set_state(response)
		end)
	end

	state
end
```

Be careful to have your [`@use_effect`](@ref) not rely on `state`, because it will most likely not have a reference to the latest state, but to the `state` at the moment that the [`@use_effect`](@ref) first ran.

To circumvent the most common case where this is a problem, you can pass a function to `set_state` that recieves the previous state as an argument:

```julia
counter = begin
	state, set_state = @use_state(0)

	@use_effect([]) do
		schedule(Task() do
			while true
				sleep(1)
				set_state(function(previous_state)
					previous_state + 1
				end)
			end
		end)

		# In the real world this should also return a cleanup function,
		# More on that in the docs for @use_effect
	end

	state
end
```
"""
macro use_state(initial_value)
	if !is_inside_pluto(__module__)
		return quote
			($(esc(initial_value)), x -> nothing)
		end
	end
	
	quote
		rerun_cell_fn = @give_me_rerun_cell_function()
		state_ref = @use_ref($(esc(initial_value)))

		# But there are no deps! True, but this takes care of initialization,
		# and the case that @use_deps creates, where we switch the cell_id around.
		# if @use_did_deps_change([])
		# 	state_ref[] = $(esc(initial_value))
		# end

		# TODO Make set_state throw when used after a cell is disposed
		# .... (so this would require @use_effect)
		# .... Reason I want this is because it will help a bunch in spotting
		# .... tasks that don't get killed, stuff like that.
		set_state = (new) -> begin
			new_value = if hasmethod(new, Tuple{typeof(new)})
				new(state_ref[])
			else
				new
			end

			state_ref[] = new_value
			rerun_cell_fn()
		end
		(state_ref[], set_state)
	end
end

# ╔═╡ cd048a16-37f5-455e-8b6a-c098d5f83b96
"""
	@use_deps(deps::Vector) do
		# ... others hooks ...
	end

Experimental function to wrap a bunch of macros in a fake cell that fully refreshes when the deps provided change. This is useful if you make a macro that wraps a bunch of Pluto Hooks, and you just want to refresh the whole block when something changes. This also clears [`@use_ref`](@ref)'s and [`@use_state`](@ref)'s, even though these don't even have a deps argument.

Not entirely sure how much this is necessary (or if I'm missing something obvious that doesn't make it necessary).

Also, this name does **not** spark joy.
"""
macro use_deps(fn_expr, deps)
	if !is_inside_pluto(__module__)
		return quote
			$(esc(deps))

			$(esc(fn_expr))()
		end
	end

	cell_id_ref = Ref{UUID}(uuid4())

	quote
		if @use_did_deps_change($(esc(deps)))
			$cell_id_ref[] = uuid4()
		end

		with_cell_id($(esc(fn_expr)), $cell_id_ref[])
	end
end

# ╔═╡ 89b3f807-2e24-4454-8f4c-b2a98aee571e
"""
	@use_effect(deps::Vector{Any}) do
		# Side effect
		return function()
			# Cleanup
		end
	end

Used to run a side effects that can create long running processes. A good example of this would be a HTTP server, or a task that runs an async process. Maybe it's a veeeery long running HTTP request, possibly a websocket connection to an API. 🌈

Likely to be used with [`@use_state`](@ref), as without it it's kinda useless. You want to get the values you fetch in the `@use_effect` back into the notebook, and that is what `@use_state` is for.

The function returned from `@use_effect` is called whenever the process is supposed to be stopped. This is either when the deps change, the cell is explicitly re-run or the cell is deleted. Make sure you write good cleanup functions! It's often seen as an afterthought, but it can make your notebook experience so much better.

```julia
# Ping me if you have a better real world example that uses deps
# Also don't copy this verbatim, we'll have `@use_task` that is smarter
#   with it's cleanup and returns the task state!
@use_effect([log_prefix])
	task = schedule(Task() do
		while true
			sleep(1)
			@info "
		end
	end)

	return function()
		Base.schedule(task, InterruptException(), error=true)
	end
end
```
"""
macro use_effect(f, deps)
	if !is_inside_pluto(__module__)
		return quote
			$(esc(deps))
			$(esc(f))()
		end
	end
	
	# For some reason the `cleanup_ref` using @use_ref or assigned outside the
	# 	`register_cleanup_fn() do ... end` (and not interpolated directly into it)
	# 	is `nothing` when the cleanup function actually ran...
	# Honestly, no idea how that works, like... `cleanup_ref[]` can be nothing sure,
	# 	but `cleanup_ref` self can be `nothing`???
	cleanup_ref = Ref{Function}(() -> nothing)
	quote
		cleanup_ref = $(cleanup_ref)

		register_cleanup_fn = @give_me_register_cleanup_function()
		register_cleanup_fn() do
			$(cleanup_ref)[]()
		end

		if @use_did_deps_change($(esc(deps)))
			cleanup_ref[]()

			local cleanup_func = $(esc(f))()
			if cleanup_func isa Function
				cleanup_ref[] = cleanup_func
			end
		end

		nothing
	end
end

# ╔═╡ 3f632c14-5f25-4426-8bff-fd315db55db5
export @use_ref, @use_state, @use_memo, @use_effect, @use_deps

# ╔═╡ c461f6da-a252-4cb4-b510-a4df5ab85065
"""
	@use_did_deps_change(deps::Vector{Any})

The most base-level `use_xxx` macro that we have, and I hope we can make it so you don't actually need this in your own code. It will, when called with deps, return `true` if the deps imply a refresh.

It will always return `true` when run the first time.
After that it will.

1. `deps=nothing` will return `true`
2. `deps=[]` will return `false`
3. `deps=[something_else...]` will return true when the deps are different than they were before
"""
macro use_did_deps_change(deps)
	if !is_inside_pluto(__module__)
		return quote
			$(esc(deps))
			true # Simulates the first run 
		end
	end
	
	# Can't use @use_ref because this is used by @use_ref
	initialized_ref = Ref(false)
	last_deps_ref = Ref{Any}(nothing)
	last_cell_id_ref = Ref{Any}(nothing)

	quote
		initialized_ref = $(initialized_ref)
		last_deps_ref = $(last_deps_ref)
		last_cell_id_ref = $(last_cell_id_ref)

		current_deps = $(esc(deps))
		current_cell_id = @give_me_the_pluto_cell_id()

		if initialized_ref[] == false
			initialized_ref[] = true
			last_deps_ref[] = current_deps
			last_cell_id_ref[] = current_cell_id
			true
		else
			# No dependencies? Always re-render!
			if current_deps === nothing
				true
			elseif (
				# There is a problem here with either cell_id or one of the deps
				# being missing... >_> Not sure what would be good here,
				# === would fix missing, but would also make all comparisons strict.
				# Explicitly checking for missing... ? 🤮
				last_deps_ref[] == current_deps &&
				last_cell_id_ref[] == current_cell_id
			)
				false
			else
				last_deps_ref[] = current_deps
				last_cell_id_ref[] = current_cell_id
				true
			end
		end
	end
end

# ╔═╡ 84736507-7ea9-4b4b-9b70-b1e9b4b33cde
md"""
### Until I get the PlutoTest PR out
"""

# ╔═╡ 118991d7-f470-4775-ac44-4638f4989d58
md"""
## PlutoRunner-based internals

These are, I hope, the only parts that need to explicitly reference PlutoRunner.
Each of these inserts a reference to a special PlutoRunner object into the resulting expression, and that special object will be caught by PlutoRunner while evaluating the cell, and replaced with the actual value.

It seems a bit over-engineered, and I guess it is, BUT, this makes it possible to have a very strict sense of what cell is actually running what function. Also it allows other macros (specifically [`@use_deps`](@ref)) to insert it's own values instead of Plutos, thus kinda creating a cell-in-a-cell 😏
"""

# ╔═╡ 405fb702-cf4a-4d34-b8ed-d3258a61256b
const overwritten_cell_id = Ref{Union{Nothing,UUID}}(nothing)

# ╔═╡ 39aa6082-40ca-40c3-a2c0-4b6221edda32
"""
	@give_me_the_pluto_cell_id()

> ⚠️ Don't use this directly!! if you think you need it, you might actually need [`@use_did_deps_change([])`](@ref) but even that is unlikely.

Used inside a Pluto cell this will resolve to the current cell UUID.
Outside a Pluto cell it will throw an error.
"""
macro give_me_the_pluto_cell_id()
	if is_running_in_pluto_process()
		:(something(overwritten_cell_id[], dont_be_pluto_special_value($(Main.PlutoRunner.GiveMeCellID()))))
	else
		:(throw(NotRunningInPlutoCellException()))
	end	
end

# ╔═╡ d9d14e60-0c91-4eec-ba28-82cf1ebc115f
"""
	@use_is_pluto_cell()

Returns whether or not this expression is running inside a Pluto cell.
This goes further than checking if the process we're running in is started using Pluto, this actually checks if this code is part of the code that gets evaluated within a cell. Meant to be used directly in a Pluto cell, or returned from a macro.

This is nestable, so you can use `@use_is_pluto_cell()` inside your macro own and, as long as that macro is used in a Pluto cell directly, it will return true.

Using this inside a function will return whether or not that function is defined in a Pluto cell. If you then call that function from a script, it will still return true:

```julia
# 49cb409b-e564-47aa-9dae-9bc5bffa991d
function wrong_use_of_use_is_pluto_cell()
	return @use_is_pluto_cell()
end

# 49cb409b-e564-47aa-9dae-9bc5bffa991d
# eval circumvents Pluto-ness
eval(quote
	@use_is_pluto_cell() // false
	wrong_use_of_use_is_pluto_cell() // true
end)
```
"""
macro use_is_pluto_cell()
	# Normally you don't need this,
	# but for some reason skip_as_script seems to want it still
	var"@give_me_the_pluto_cell_id"

	give_me_cell_id = is_running_in_pluto_process() ?
		Main.PlutoRunner.GiveMeCellID() :
		nothing
	
	quote
		if (
			is_running_in_pluto_process() &&
			$(give_me_cell_id) != Main.PlutoRunner.GiveMeCellID()
		)
			true
		else
			false
		end
	end
end

# ╔═╡ cce13aec-7cf0-450c-bc93-bcc4e2a70dfe
"""
	@skip_as_script expr

Only run the expression if you're running inside a pluto cell. Small wrapper around [`@use_is_pluto_cell`](@ref).

"""
macro skip_as_script(expr)
	var"@use_is_pluto_cell"

	quote
		if @use_is_pluto_cell()
			$(esc(expr))
		else
			nothing
		end
	end
end

# ╔═╡ 71963fa5-82f0-4c8d-9368-0d6ba317f59e
# Notice that even though we run it in this cell's module,
# that doesn't count as "being in Pluto" enough.
@skip_as_script let
	is_pluto_cell = eval(quote
		@use_is_pluto_cell()
	end)
	if is_pluto_cell
		error("❌ eval() thinks it is a Pluto cell! What!!")
	else
		md"✅ Nice, eval() is indeed not the Pluto cell"
	end
end

# ╔═╡ ec74d9b7-b2ff-4758-a305-c3f30509a786
"""
	@only_as_script expr

Only run the expression if you're **not** running inside a pluto cell. Small wrapper around [`@use_is_pluto_cell`](@ref).

"""
macro only_as_script(expr)
	var"@use_is_pluto_cell"

	quote
		if @use_is_pluto_cell()
			nothing
		else
			$(esc(expr))
		end
	end
end

# ╔═╡ 92cfc989-5862-4314-ae1b-9cbfc4b42b40
export @use_is_pluto_cell, @skip_as_script, @only_as_script

# ╔═╡ 014d0172-3425-4429-b8d6-1d195bc60a66
@skip_as_script let
	if @use_is_pluto_cell()
		md"✅ Nice, we are indeed running in Pluto"
	else
		error("❌ Uhhhhhh")
	end
end

# ╔═╡ 3d2516f8-569e-40e4-b1dd-9f024f9266e4
"""
	@give_me_rerun_cell_function()

> ⚠️ Don't use this directly!! if you think you need it, you need [`@use_state`](@ref).

Used inside a Pluto cell this will resolve to a function that, when called, will cause the cell to be re-run (in turn re-running all dependent cells).
Outside a Pluto cell it will throw an error.
"""
macro give_me_rerun_cell_function()
	if is_running_in_pluto_process()
		:(dont_be_pluto_special_value($(Main.PlutoRunner.GiveMeRerunCellFunction())))
	else
		:(throw(NotRunningInPlutoCellException()))
	end
end

# ╔═╡ cf55239c-526b-48fe-933e-9e8d56161fd6
"""
	@give_me_register_cleanup_function()

> ⚠️ Don't use this directly!! if you think you need it, you need [`@use_effect`](@ref).

Used inside a Pluto cell this will resolve to a function that call be called with yet another function, and then will call that function when the cell gets explicitly re-run. ("Explicitly re-run" meaning all `@use_ref`s get cleared, for example).
Outside a Pluto cell it will throw an error.
"""
macro give_me_register_cleanup_function()
	if is_running_in_pluto_process()
		:(dont_be_pluto_special_value(
			$(Main.PlutoRunner.GiveMeRegisterCleanupFunction())
		))
	else
		:(throw(NotRunningInPlutoCellException()))
	end	
end

# ╔═╡ 86a2f051-c554-4a1c-baee-8d01653c15be
"""
	with_cell_id(f, cell_id)

> ⚠️ Don't use this directly!! if you think you need it, you need [`@use_deps`](@ref).

Used inside a cell to get the "proxy" cell id. This could be the real one but also a fake one in case your hook is called from another hook.
"""
function with_cell_id(f::Function, cell_id)
	previous_cell_id = overwritten_cell_id[]
	overwritten_cell_id[] = cell_id
	try
		f()
	finally
		overwritten_cell_id[] = previous_cell_id
		nothing
	end
end

# ╔═╡ b36e130e-578b-42cb-8e3a-763f6b97108d
md"""
### Very cool small helpers

These are just to make [`@give_me_the_pluto_cell_id`](@ref), [`@give_me_rerun_cell_function`](@ref) and [`@give_me_register_cleanup_function`](@ref) throw whenever you're not in Pluto.

One more reason to not call these directly.
"""

# ╔═╡ ff97bcce-1d29-469e-a4be-5dc902676057
Base.@kwdef struct NotRunningInPlutoCellException <: Exception end

# ╔═╡ 78d28d07-5912-4306-ad95-ad245797889f
function Base.showerror(io::IO, expr::NotRunningInPlutoCellException)
	print(io, "NotRunningInPlutoCell: Expected to run in a Pluto cell, but wasn't! We'll try to get these hooks to work transparently when switching from Pluto to a script.. but not yet, so just as a precaution: this error!")
end

# ╔═╡ 1b8d6be4-5ba4-42a8-9276-9ef687a8a7a3
if is_running_in_pluto_process()
	function dont_be_pluto_special_value(x::Main.PlutoRunner.SpecialPlutoExprValue)
		throw(NotRunningInPlutoCellException())
	end
end

# ╔═╡ f168c077-59c7-413b-a0ac-c0fd72781b72
dont_be_pluto_special_value(x::Any) = x

# ╔═╡ 9ec6b9c5-6bc1-4033-ab93-072f783184e9
md"""
### Until I get the PlutoTest PR out
"""

# ╔═╡ fd653af3-be53-4ddd-b69d-3967ef6d588a
md"#### `@give_me_the_pluto_cell_id()`"

# ╔═╡ b25ccaf1-cf46-4eea-a4d9-16c68cf56fad
@skip_as_script try
	eval(quote
		@give_me_the_pluto_cell_id()
	end)
	error("❌ This should throw a NotRunningInPlutoCellException.. but didn't!")
catch e
	if e isa NotRunningInPlutoCellException
		md"✅ Nice, we got an exception like we should"
	else
		rethrow(e)
	end
end

# ╔═╡ e5905d1e-33ec-47fb-9f98-ead82eb03be8
@skip_as_script begin
	cell_id = @give_me_the_pluto_cell_id()
	if cell_id isa UUID
		md"✅ Nice, we got the cell UUID"
	else
		error("❌ What the? Got a typeof($(typeof(cell_id)))")
	end
end

# ╔═╡ 274c2be6-6075-45cf-b28a-862c8bf64bd4
md"""
## Examples/Experiments

Ideally, these functions would be in their own package (so they can update without PlutoHooks updating), but for now we keep them here to show of and test the stuff above.
"""

# ╔═╡ 90f051be-4384-4383-9a56-2aa584687dc3
macro use_reducer(fn, deps=nothing)
	quote
		ref = @use_ref(nothing)
	
		current_value = ref[]
		if @use_did_deps_change($(esc(deps)))
			next_value = $(esc(fn))(current_value)
			ref[] = next_value
		end
	
		ref[]
	end
end

# ╔═╡ c8c560bf-3ef6-492f-933e-21c898fb2db6
md"### `@use_task`"

# ╔═╡ 9ec99592-955a-41bd-935a-b34f37bb5977
macro use_task(f, deps)
	quote
		error("@use_task was moved to PlutoLinks.jl")
	end
end

# ╔═╡ 56f2ff19-c6e8-4858-8e6a-3b790fae7ecb
md"### `@use_file(filename)`"

# ╔═╡ e240b167-560c-4dd7-9801-30467d8758be
macro use_file_change(filename)
	quote
		error("@use_file_change was moved to PlutoLinks.jl")
	end
end

# ╔═╡ 461231e8-4958-46b9-88cb-538f9151a4b0
macro use_file(filename)
	quote
		error("@use_file was moved to PlutoLinks.jl")
	end
end

# ╔═╡ 9af74baf-6571-4a0c-b0c0-989472f18f7a
md"### `@ingredients(julia_file_path)`"

# ╔═╡ d84f47ba-7c18-4d6c-952c-c9a5748a51f8
macro ingredients(filename)
	quote
		error("@ingredients was moved to PlutoLinks.jl")
	end
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
UUIDs = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
"""

# ╔═╡ Cell order:
# ╟─729ae3bb-79c2-4fcd-8645-7e0071365537
# ╠═49cb409b-e564-47aa-9dae-9bc5bffa991d
# ╠═3f632c14-5f25-4426-8bff-fd315db55db5
# ╠═92cfc989-5862-4314-ae1b-9cbfc4b42b40
# ╟─c82c8aa9-46a9-4110-88af-8638625222e3
# ╟─1df0a586-3692-11ec-0171-0b48a4a1c4bd
# ╟─cd048a16-37f5-455e-8b6a-c098d5f83b96
# ╟─89b3f807-2e24-4454-8f4c-b2a98aee571e
# ╟─bc0e4219-a40b-46f5-adb2-f164d8a9bbdb
# ╟─c461f6da-a252-4cb4-b510-a4df5ab85065
# ╟─0f632b57-ea01-482b-b93e-d69f962a6d92
# ╟─d9d14e60-0c91-4eec-ba28-82cf1ebc115f
# ╟─cce13aec-7cf0-450c-bc93-bcc4e2a70dfe
# ╟─ec74d9b7-b2ff-4758-a305-c3f30509a786
# ╟─8c2e9cad-eb63-4af5-8b52-629e8d3439bd
# ╟─df0645b5-094a-45b9-b72a-ab7ef9901fa1
# ╟─84736507-7ea9-4b4b-9b70-b1e9b4b33cde
# ╟─014d0172-3425-4429-b8d6-1d195bc60a66
# ╟─71963fa5-82f0-4c8d-9368-0d6ba317f59e
# ╟─118991d7-f470-4775-ac44-4638f4989d58
# ╟─405fb702-cf4a-4d34-b8ed-d3258a61256b
# ╟─39aa6082-40ca-40c3-a2c0-4b6221edda32
# ╟─3d2516f8-569e-40e4-b1dd-9f024f9266e4
# ╟─cf55239c-526b-48fe-933e-9e8d56161fd6
# ╟─86a2f051-c554-4a1c-baee-8d01653c15be
# ╟─b36e130e-578b-42cb-8e3a-763f6b97108d
# ╠═ff97bcce-1d29-469e-a4be-5dc902676057
# ╟─78d28d07-5912-4306-ad95-ad245797889f
# ╟─1b8d6be4-5ba4-42a8-9276-9ef687a8a7a3
# ╟─f168c077-59c7-413b-a0ac-c0fd72781b72
# ╟─9ec6b9c5-6bc1-4033-ab93-072f783184e9
# ╟─fd653af3-be53-4ddd-b69d-3967ef6d588a
# ╟─b25ccaf1-cf46-4eea-a4d9-16c68cf56fad
# ╟─e5905d1e-33ec-47fb-9f98-ead82eb03be8
# ╟─274c2be6-6075-45cf-b28a-862c8bf64bd4
# ╟─90f051be-4384-4383-9a56-2aa584687dc3
# ╟─c8c560bf-3ef6-492f-933e-21c898fb2db6
# ╠═9ec99592-955a-41bd-935a-b34f37bb5977
# ╟─56f2ff19-c6e8-4858-8e6a-3b790fae7ecb
# ╠═e240b167-560c-4dd7-9801-30467d8758be
# ╠═461231e8-4958-46b9-88cb-538f9151a4b0
# ╟─9af74baf-6571-4a0c-b0c0-989472f18f7a
# ╠═d84f47ba-7c18-4d6c-952c-c9a5748a51f8
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
