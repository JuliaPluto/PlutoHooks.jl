# PlutoHooks.jl

Get hooked on Pluto! Bring your notebook to life! This is an abstraction based on [React.js Hooks](https://reactjs.org/docs/hooks-intro.html) to implement "react-like" features in [Pluto.jl](https://plutojl.org).
It allows code cells to carry information and processes between updates, and even update themselves.
The PlutoHooks macros are used as a foundation for the higher-level utilities in [PlutoLinks.jl](https://github.com/JuliaPluto/PlutoLinks.jl). The source code is written as a Pluto notebook, which also serves as [package documentation](https://juliapluto.github.io/PlutoHooks.jl/src/notebook.html).

There is a lot you can do with this, but some examples:
- Maintain state between cell evaluations.
- Run a process and relay its output to the rest of your notebook.
- Watch a file and reload the content when it changes.
- Do a computation on separate thread while the rest of notebook continue running.

This requires using Pluto with a version higher than 0.17.2.
