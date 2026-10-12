# ChrysaLisp's GPU burst, and what Aether / ae3d might do about it

For Nic, from Paul (written up with Claude), 2026-10-06, updated after Chris's afternoon commits (to `9db12a8a1`), and again on 2026-10-12 (to `3326d4333`, section 1b).

Our checkout of ChrysaLisp is `~/scm/not-ours/Cyl` (Paul's fork,
`paul-hammant/ChrysaLisp_AI_made_apps_experiment`). It sits under `not-ours/`
on purpose: we read it for ideas and never copy, port or paraphrase its code
into ours, whatever its licence.

## 1. What Chris did

Over 5–6 October 2026 Chris Hinsley pushed about 55 commits to ChrysaLisp, all
Claude-aided. His own summary, sent partway through:

> No GPU at all! … our own VP-GPU-CODE to native translator … in effect we now
> have the vp-simd instructions but for real … Now have our own SFX mixer.
> Updated to sdl3. Our own gui events system, new software backends, GPU shader
> language. And compiler. Backends for metal and spir-v.

What is actually in the tree at `2232a1230` (checked against the code, not the
announcement):

| Piece | Where | State |
|---|---|---|
| Shader language written as s-expressions | `lib/gpu/shader.inc` (442 lines) | Working. A shader is a Lisp list: `(defun hash :float ((n :float)) (fract (* (sin n) 43758.5453)))` |
| GLSL back end | `lib/gpu/glsl.inc` (83 lines) | Working |
| Metal (MSL) back end | `lib/gpu/msl.inc` (128 lines) | Proven through SDL3 GPU on a Mac |
| **SPIR-V back end** | `lib/gpu/spirv.inc` (339 lines) | Run on a Raspberry Pi 4's GPU, and on Windows (Vulkan). Writes the binary words itself, no glslang |
| CPU back end | `lib/gpu/cpu.inc` (287 lines) | Working, interpreted |
| VP back end: shader → VP assembly → native code | `lib/gpu/vp.inc` (676 lines) | Working. The surface demo raymarches at 640×480 with no GPU |
| `shader` command | `cmd/shader.lisp` | Compiles a shader from the command line, to the screen or a file |
| SDL3 GUI driver | `src/host/gui_sdl3.cpp` | Now the **default**. Run on Macs, a Pi 4 on a bare display (no desktop), and Windows. Not yet on a Linux X11/Wayland desktop |
| Mixer | `src/host/mixer.h` | Its own file with no SDL in it. Limits a loud mix instead of clipping, easing in from 90% of full scale |
| GUI events of ChrysaLisp's own, not copies of SDL2 structs | host | Done |

The later commits also show good engineering around the GPU:

- **Shaders build on a thread.** The CPU back end draws the picture while the
  driver compiles the shader, then the GPU takes over (`cd58b39ef`,
  `1453d5040`).
- **Drawing goes a strip at a time**, off screen, and only whole frames are
  shown, so a slow GPU like the Pi's doesn't freeze the GUI (`a2ddef8aa`,
  `010d28953`).
- **The SDL3 driver asks for a GPU device without features a small GPU lacks**
  (`03f920985`).
- **The language got tidier.** Declarations are now `definput`, `defconst` and
  `defglobal`, and a function's value is its last form, with `return` only for
  leaving early (`caa5fc146`, `19b3d736a`).

Chris has since drafted the **ChrysaLisp 7.1 release notes**
(`docs/releases/v7.1.md`, not yet tagged), which gather all this together
with measured figures:

- **Native vs interpreted**: the VP native back end is 37× faster than the Lisp
  back end on Macs and 84× on a Pi 4. The raymarch at 320×240 on one core takes
  219ms on an M4, 377ms on a 2018 x86_64 MacBook Pro and 913ms on the Pi. The
  native code has run on ARM64, x86_64, the VP64 emulator, and RISC-V 64 and
  LoongArch 64 under QEMU.
- **GPU vs CPU**: at 640×480 on an M4 Max the GPU keeps up with the demo's
  60fps timer. With no GPU, the frame takes 76–96ms spread over 16 nodes.
- **The Pi's GPU over Vulkan** stays within 0.0025 of the CPU back end on every
  pixel and takes about 400ms per 640×480 frame. Its driver takes 18 seconds
  to build the shader the first time, which is why building on a thread
  matters.
- **The interpreted Lisp back end is the reference** that the other four are
  checked against. That's the same role we have in mind for a CPU evaluator in
  section 4.
- **`shader -t glsl|msl|spirv|vp|cpu|tree -o file`** makes the language usable
  outside ChrysaLisp: a shader written there can be handed to any GLSL, Metal
  or Vulkan program.
- **Credit**: the notes thank Darren Pegg for the `def` names, for asking why a
  function had to say `return`, and for asking to see what a shader compiles
  to. So some of the afternoon's language tidying came from a user asking
  questions.

Where the announcement still runs ahead of the code:

- **"vp-simd for real"**: the VP back end still does not use `vp-simd`. The doc
  says: "The VP code is plain scalar code … there is no SIMD." It also has no
  register spill, so a shader needing more than 16 float registers is refused.
- **SPIR-V checking**: his doc says the SPIR-V output has been compared with the
  other back ends on the raymarch shader only. The test suite's small shaders
  are checked for form.
- **Scope**: one real shader, the raymarch, as a fragment shader only. Vertex
  shaders, meshes, textures as inputs and compute are all listed as not yet
  done.

So it is still small, about 2,000 lines for the whole stack. It isn't "very very
advanced" in breadth. **What's impressive is how much it gets from so little
code, and how fast it moves.** SPIR-V went from "not here yet" to running on a
Pi in about seven hours. A shader written as s-expressions is already a syntax
tree, so each back end is just a walk over that tree. GLSL takes 83 lines, and
SPIR-V, *binary*, takes 339 with no external compiler. One shader source now
gives GLSL, Metal, SPIR-V, an interpreted CPU fallback and native code.

## 1b. Since then: 6 to 12 October (to `3326d4333`)

Chris (and his Claude) is on a roll: **437 more commits in six days**, all
his, about 100 a day at the peak (8 to 10 October). ChrysaLisp 7.2 and 7.3
are written up in `docs/releases/`. Most of it is off the GPU: a
content-addressed storage service spread over several machines, machines
that find each other and form a mesh (`mesh`, `sync`, `rack`), a whiteboard
app, SHA-512 and Ed25519, a source-checking tool, and the VP assembler's
expressions as forms. The GPU part is what matters to us:

| Then (`9db12a8a1`) | Now (`3326d4333`) |
|---|---|
| About 2,000 lines in `lib/gpu/` | 4,075: `vp.inc` 1,759, `shader.inc` 700, `cpu.inc` 517, `spirv.inc` 495, `msl.inc` 231, `glsl.inc` 150, plus `tris`, `gui` and `tile` |
| Fragment shaders only, one real shader (the raymarch) | **Vertex shaders too**: `defattr` (what a vertex gives), `defvarying` (what is handed to the pixel shader), a `:mat4`. One vertex shader serves any pixel shader whose varyings it has. Six shaders in `lib/gpu/shaders/` |
| No meshes | **Triangles**, with a depth buffer, clipping at the near plane, and alpha. Drawn as native code (20,000 triangles at 900×900 in 12ms on one core), with the Lisp reference matching it to the bit |
| GPU drew a full-screen picture | **Meshes on the GPU** through Metal on a Mac and Vulkan on a Pi 4 and Windows. The mesh stays on the GPU; the host has calls for a shader pair, a mesh and a frame. 4× multisampling where the device has it. The Pi draws the Mesh demo in 36ms a frame, where three of its cores take 62 to 98ms. The SPIR-V modules pass `spirv-val` |
| GLSL fragment only | GLSL has a vertex stage too, checked by compiling as GLSL ES 1.00 and desktop 1.20. No host draws with it yet |
| Shaders only | **Typed functions that Lisp calls as native code**: a file with no `main` is a set of functions, e.g. a matrix product, and these run as fast as the hand-written VP (52ns for a mat4 product on an M4 Max). "Compute on the CPU first"; GPU compute is still to come |
| Built each time | **Kept by hash.** Native code, Metal text and SPIR-V are cached under the SHA-256 of the shader file *and* a hash of the back end's own source. Change a back end and its old output is simply not found: there is no version number to remember to bump |

Checking got broader too. The test module has 157 tests and passes on ARM64
macOS, a Pi 4, x86_64 macOS, RISC-V 64 and LoongArch 64 under QEMU, and the
VP64 emulator. CPU (doubles) against GPU (32-bit floats) differs by at most
about 0.01 per pixel on the raymarch, except for a `fract(sin(n) * 43758.5)`
hash that depends on the float's last bits. Chris explains that difference
instead of hiding it.

Still not there, by his own list: **textures as inputs**, **GPU compute**,
register spill in the VP back end (more than 16 float registers is refused),
SIMD, and guarding GLSL's reserved words. Textures are exactly what our
FXAA example needs (`aether_quote_design.md`, section 6), and ae3d's
post-processing is mostly texture reads.

## 2. Where we stand

**ae3d** is far ahead on rendering. Its shaders do TAA, SSR, SSAO, FXAA, bloom,
sky, depth resolve, crowds, plus compute shaders for crowd sorting and skinning.
Around them sit IK, locomotion, horde, water, weather, terrain and the rest.
Chris has nothing near this. Since section 1b he has vertex shaders, meshes
and a depth buffer, but still no textures as inputs and no compute, and ae3d
needs both.

But ae3d's shaders are GLSL text in heredocs (`src/ae3d/shaders/module.ae`,
about 4,300 lines), with a second set of 24 `_vk` variants under
`src/ae3d/vkspirv/glsl/`. `tools/generate_shaders.ae` compiles those to SPIR-V.
So we keep two GLSL dialects by hand, Metal would need a third, and a CPU
fallback isn't possible at all. The shaders are text, and nothing in Aether can
look inside them.

**Aether** has DSL-with-scope (closures, trailing blocks, the builder context
stack; see `aether/docs/closures-and-builder-dsl.md`). The aether-ui calculator
shows it off:
`window(…) { vstack(…) { hstack(…) { btn("7") callback { … } } } }`.

That builds **structure** well. Code inside a block, though, is ordinary code
compiled to C: `x * sin(n)` computes a number. A shader DSL needs each
**expression as data**, a tree it can print as GLSL, MSL or SPIR-V, or run on
the CPU. That is the gap between us and Chris, and it comes down to the
language, not the engine.

## 3. Three ways to close the gap

### Option 1: expression builders (library only)

```aether
c = vec4(mul(x, sin(n)), 0.0, 0.0, 1.0)   // each call builds a node
```

- No compiler change, so it could start today in an ae3d module.
- It reads worse than the s-expressions it imitates, and worse than the GLSL it
  replaces. Operators, `if` and loops all become calls.
- **Verdict**: good for a prototype to test the back ends, not for writing 24
  shaders.

### Option 2: a shader subset in the compiler

```aether
shader fn sky_frag(uv: vec2): vec4 {
    return vec4(sin(uv.x * 10.0), 0.0, 0.0, 1.0)
}
```

- The compiler type-checks a restricted subset (vector types, no heap, no
  actors) and emits GLSL or SPIR-V from the syntax tree, instead of C.
- The same approach as Rust-GPU, Slang and C++ AMP.
- Translation happens at build time, so the result can be checked by
  `glslangValidator` in CI.
- The emitters live inside the compiler, in C. Each new target (Metal, WGSL,
  CPU) is a compiler change, and the machinery serves shaders only.

### Option 3: add quoting to the language

**Quoting** means telling the compiler to hand over the code itself as a tree
of data, instead of compiling it to run. Lisp gets this for free (`'(* x (sin
n))`). Other languages added it later:

- **C# expression trees.** This is how LINQ-to-SQL turns `p => p.Age > 30` into
  `WHERE age > 30`, and the closest model for us.
- **Julia** `:(…)` and **Elixir** `quote do … end`.

In Aether it would be a **fourth trailing-block form**, alongside immediate,
closure and callback:

```aether
time = 0.0
sky = shader("sky") quote |uv: vec2| {
    t = time * 0.1
    return vec4(sin(uv.x * 10.0 + t), 0.0, 0.0, 1.0)
}
glsl = shader.to_glsl(sky)    // ordinary Aether library code walks the tree
```

- The compiler type-checks the block as usual. Instead of C for the body, it
  emits C that **builds the tree** at runtime.
- **A captured outer variable** (`time` above) arrives as a node that says
  "captured `time`". A shader library can turn that node into a uniform
  automatically, the step that is usually fiddly by hand. C# works the same way.
- **Back ends are Aether libraries**, not compiler code. GLSL, SPIR-V, MSL, WGSL
  and a CPU evaluator could each be added without touching the compiler.
- **It's useful beyond shaders**: query builders, symbolic maths, and test
  failures that print the asserted expression (`expect(a + b == c)` reporting
  each side). The aether-ui and build DSLs could use it too.
- **The costs**:
  - The syntax-tree types become public, and we'd have to keep them stable.
  - Translation happens at runtime, at startup, which is fine since ae3d already
    loads shaders at startup.
  - Doing it at build time, as Chris can with Lisp macros, would mean running
    Aether code inside the compiler. That's a much bigger step, because Aether
    compiles via C.

### Recommendation

**Option 3**, with Option 1 as its scaffolding. Option 1's node types and
GLSL emitter are the very library that Option 3's quoted trees would feed into.
So the work isn't thrown away, and we can prove the back ends before touching
the compiler. Fall back to Option 2 only if keeping public syntax-tree types
stable looks too costly.

## 4. Things we should do

1. **Pick one small ae3d shader and port it by hand** (`passthrough_vk.frag`
   or `fxaa_vk.frag`) into each option's syntax, side by side. That's the
   cheapest way to see which reads best, and it costs an afternoon.
2. **Build the node types and a GLSL emitter as a plain Aether module**
   (Option 1). Check that it reproduces the hand-written GLSL for that shader
   byte-for-byte, or at least the same SPIR-V once compiled.
3. **Add a CPU evaluator for the same nodes.** That gives us Chris's
   "no GPU at all" fallback, golden-image tests in CI without a GPU, and a
   check on every back end, since GPU and CPU results must match within a
   tolerance.
4. **Design `quote` as a trailing-block form** (Option 3): the syntax,
   what a capture becomes, which subset of the language is allowed, and what
   errors look like. Write it up in `aether/docs/` next to
   `closures-and-builder-dsl.md` before building it. *Drafted:*
   `docs/aether_quote_design.md` on this branch.
5. **Use ae3d's shaders as the test set.** Migrate one shader at a time, and
   keep `tools/generate_shaders.ae` working throughout. The first payoff is
   retiring the duplicated GL and `_vk` GLSL variants, with one source emitted
   in two dialects.
6. **Then add MSL**, giving ae3d its first Metal path, the same win Chris got
   from 128 lines.
7. **Later, and only if it earns its keep**: native CPU shaders (Aether to C
   to the C compiler, our version of his VP back end) and SIMD over a tile of
   pixels. That's the part Chris hasn't done yet either.
8. **Read Chris's `spirv.inc` before writing our own SPIR-V emitter**, for
   ideas only: we read it and then write ours from the SPIR-V spec. It
   writes the binary directly, 339 lines then and 495 now, with vertex
   stages. ae3d currently relies on
   glslang (`tools/generate_shaders.ae` runs `glslangValidator`). An emitter
   that writes the words itself would drop that dependency, though glslang
   should stay in CI as the checker.
9. **Borrow his runtime patterns**, which carry straight over to ae3d:
   build pipelines on a worker thread with a CPU or placeholder picture
   meanwhile, and keep slow GPUs from stalling the frame.
10. **Key generated shader output by content hash** (section 1b): the hash
    of the source together with a hash of the emitter's own source. For
    ae3d that means `tools/generate_shaders.ae`'s SPIR-V, and later whatever
    a quoted tree emits. A cache whose key changes when the emitter changes
    needs no version bump and never serves stale output.
11. **One numeric language for shaders and plain functions.** His typed
    functions for Lisp to call are the same language with arguments in
    place of a pixel. With `quote`, the same falls out for us: a quoted
    function that isn't a shader can go to the CPU evaluator or to C, and
    later to GPU compute (`aether_quote_design.md`, section 8).

## 5. Sources

- ChrysaLisp, checked out at `~/scm/not-ours/Cyl`: commits `7c6fba47f`
  (shader language) through `9db12a8a1` for sections 1 to 4, and on to
  `3326d4333` (2026-10-12) for section 1b;
  `docs/releases/v7.1.md`, `v7.2.md`, `v7.3.md`, `lib/gpu/*.inc`,
  `lib/gpu/shaders/`, `cmd/shader.lisp`,
  `docs/ai_digest/shader_language.md` (sections "Functions For Lisp To Call",
  "A file is known by a hash of it", "Do They Agree", "Limits").
- `aether/docs/closures-and-builder-dsl.md`;
  `aether-ui/examples/calculator/calculator.ae`.
- `ae3d/src/ae3d/shaders/module.ae`, `ae3d/src/ae3d/vkspirv/`,
  `ae3d/tools/generate_shaders.ae`.
