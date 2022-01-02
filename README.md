# PlutoHooks.jl

Get hooked on Pluto! Bring your notebook to life! This is an abstraction based on [React.js Hooks](https://reactjs.org/docs/hooks-intro.html) to implement "react-like" features in [Pluto.jl](https://plutojl.org).
It allows code cells to carry information and processes between updates, and even update themselves.
This package contains only the low level hooks, the directly usable hooks have been moved in [PlutoLinks.jl](https://github.com/JuliaPluto/PlutoLinks.jl). You can take a look at the [PlutoHooks.jl sources](https://juliapluto.github.io/PlutoHooks.jl/src/notebook.html).

There is a lot you can do with this, but some examples:
- Run a process and relay it's output to the rest of your notebook.
- Watch a file and reload the content when it changes.
- Do a computation on separate thread while the rest of notebook continue running.

This requires using Pluto with a version higher than 0.17.2.
