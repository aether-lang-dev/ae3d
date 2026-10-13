# Three Aether language questions from `quote` (for Nic)

From Paul (written up with Claude), 2026-10-13. `quote` is in Aether 0.810.0
(aether#2819) and ae3d now draws FXAA from a quoted shader on both renderers
(`docs/aether_quote_design.md`, step 4). Moving the next shaders hit three
questions that are language design, not bugs, so they want your view before
anyone builds anything. Three smaller gaps found the same way (a qualified
struct type such as `*gpu.GpuShader` not parsing, an `INT64_MIN` literal
clang warns on, and a lane component typed `f32` in a quote's tree) are
handled in aether#2891 and are not covered here. (The last stays `f32`:
it is the honest type of a 32-bit lane, and the docs now say a GLSL back
end maps both `float` and `f32` to GLSL's `float`.)

Each section: the problem, the options, a recommendation.

## 1. A shader can't call its own helper functions

**The problem.** In a quote, a call to a function of the program is
recorded as a `CALL` node with the function's name. The tree does not hold
the callee's body, so a back end that writes GLSL has nothing to write for
it. FXAA has no helpers, so it didn't notice. Bloom's downsample has four:

```glsl
vec3 tap(vec2 offset) { return texture(screenTexture, TexCoords + offset * texelSize).rgb; }
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 group(vec3 a, vec3 b, vec3 c, vec3 d) { /* weights by luma(...) */ }
vec3 past_threshold(vec3 c) { /* a soft knee, using luma(...) */ }
```

So bloom, and most shaders after it, are blocked: today the only way is to
inline the helpers by hand.

Builtins (`dot`, `texture`, `smoothstep`) are fine as they are: the library
declares them, the emitter knows their GLSL names, and their bodies are the
CPU evaluator's. The gap is a function the shader author writes.

**Options.**

- **A. Library-side registry, no compiler change.** The author writes each
  helper as its own quote and hands it to the library by name:
  `lib.helper("luma") quote | c: vec3 | -> dot(c, LUMA)`. The shader then
  calls `luma(c)`, which type-checks against a plain Aether `luma` declared
  beside it. Works today, but the helper is written twice (once quoted, once
  as the Aether function the checker needs), and nothing makes the two agree.
- **B. An annotation that keeps a function's tree, `@quotable`.** The
  compiler compiles the function as usual and also keeps its tree (the same
  lowering a quote gets). A `CALL` to a `@quotable` function carries a link
  to that tree (`quote.callee(n) -> Tree`), and the emitter writes each
  callee once, before `main`. One source, checked once, and the CPU
  evaluator can still call the compiled function. The cost: the tree format
  gains "a reference to another tree", and `@quotable` functions take the
  quote subset's restrictions (no `defer`, no actors, and so on).
- **C. Keep every function's tree.** The same as B with no annotation. The
  simplest to use, but every function body in every program becomes part of
  the stable tree format, and every build carries trees nobody reads.

**Recommendation: B.** It is the smallest public commitment that removes
the duplication, and the subset check gives a clear error when a helper
uses something a shader can't. C# shows what happens without it: an
expression tree can't see into a method it calls, which is why LINQ
providers can't translate a call to a user's own method.

## 2. No overloading

**The problem.** GLSL's builtins are overloaded: `min` takes floats, vec2s,
vec3s; `vec4(vec3, float)` and `vec4(float, float, float, float)` are both
`vec4`. Aether has one signature per name, so the shader library declares
one of each (`min` of floats, `vec4(vec3, float)`), and the next shaders
will need the rest.

**Options.**

- **A. A naming convention in the library, no language change.**
  `min_v3`, `vec4_xyzw`, `mix_v3`, ... The emitter maps each back to GLSL's
  name. Contained and works today, but every shader reads less like GLSL,
  and the same convention would spread to every library with a generic
  numeric surface.
- **B. Overloading by parameter types.** The usual meaning: same name,
  different parameter types, resolved at compile time. It reaches every
  library and every error message, interacts with UFCS (`x.min(y)`), with
  distinct types (does `min(USD, USD)` resolve to the float one?) and with
  C name mangling, which today is the plain name.
- **C. Overloading only for functions marked `@shader_builtin` (or
  `@overload`)**, resolved the same way but opt-in: the rest of the language
  keeps one name per function.

**Recommendation: A now, decide B (or C) on its merits.** Overloading is a
large language question that should be decided for the whole language, not
pulled in for shaders. A naming convention unblocks the shaders today; if
overloading arrives later, the convention becomes aliases and nothing else
changes.

## 3. Struct names are one namespace across modules

**The problem.** Two modules each defining `struct Shader` is error E0200
("defined differently in two modules"), because a struct's C name is its
plain name. ae3d had to name its tree types `GpuShader`, `GpuNode`,
`ShaderImage` to stay clear of `ae3d.core`'s `Shader` and others. Any two
libraries choosing an ordinary name will collide, and the user can't fix it
from their side.

**Options.**

- **A. Module-scoped struct types.** `gpu.Shader` and `core.Shader` are
  different types; the C name is mangled with the module (`ae3d_gpu_Shader`).
  Unqualified use resolves through imports as functions already do. The
  qualified spelling `*gpu.Shader` (being fixed to parse in the PR above)
  becomes the way to name another module's type. The cost: the C names
  change, which matters for `--emit=lib`'s ABI and anything that names a
  struct from C (the ABI note in aether's AGENTS.md says exported names stay
  stable, so exported structs might need an alias).
- **B. Keep one namespace, require a module prefix by convention.** What
  ae3d does now. Costs nothing, scales badly.

**Recommendation: A.** It is what every module system the language is
compared with does, and the collisions only grow with the ecosystem. The
`--emit=lib` ABI question needs your call: mangle only non-exported structs,
or mangle all and keep the old names as aliases for one release.

## What happens next

The PR for the three small gaps is aether#2891. Nothing is built for these
three until you've had a look. If you agree with the recommendations, the
order would be 1B (it unblocks bloom and most shaders after it), then 3A,
with 2 decided separately and the naming convention used meanwhile.
