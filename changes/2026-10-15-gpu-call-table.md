### One table of the calls a quoted shader may make

- **`ae3d.gpu`'s call table** lists every function a quoted shader may call:
  its Aether name (an `ae3d.shaderlib` export), what GLSL writes for it (a
  function, or a swizzle: `rgb(c)` is `c.rgb`), and how many arguments it
  takes. The GLSL is written from it and nowhere else, and a call that is not
  in it (nor a `@quotable` helper) is refused by both back ends, with a message
  naming the call, rather than written as a GLSL call that does not exist and
  left for glslang or the driver to reject. The CPU runs each by its Aether
  name, so a wrong GLSL entry shows as the CPU and the GPU disagreeing.
  `gpu.call_glsl` and `call_args` read it.
- This is Nic's option A for overloading: when Aether needs two names for
  one GLSL function, both go here.
- `tests/test_gpu.ae`: a quote calling a plain Aether function is refused by
  the GLSL writer and the CPU, each naming it. Before the table the GLSL
  writer wrote the call into the shader without complaint.
