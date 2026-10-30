# `quote`: code as data in Aether (design)

For Nic, from Paul (written up with Claude), 2026-10-12. This is step 4 of
`aether_cyl_reaction_and_directions.md` (Option 3): the design to agree on
before building anything. It is grounded in how the compiler handles trailing
blocks today. File and line references are to `aether` at v0.807.0.

The comparison throughout is ChrysaLisp's shader language, which we have
checked out at `~/scm/not-ours/Cyl` (at `3326d4333`, 2026-10-12; see section
1b of the other doc). There a shader is already an s-expression, so Lisp
gets for nothing the tree that `quote` would give us. We use it for ideas
only: no code from `not-ours/` is copied, ported or paraphrased.

## 1. What it is

A fourth trailing-block form. The compiler type-checks the block as ordinary
Aether. Instead of compiling the body to C that runs, it compiles it to C
that **builds a tree describing the body**, and passes that tree to the
function.

```aether
sky = shader("sky") quote |uv: vec2| {
    t = time * 0.1
    return vec4(sin(uv.x * 10.0 + t), 0.0, 0.0, 1.0)
}
```

`shader` is an ordinary Aether function whose last parameter is a `quote.Tree`.
What it does with the tree (print GLSL, evaluate it on the CPU, build a SQL
`WHERE`) is library code. The compiler only knows how to hand the tree over.

| Form | Written | The function gets |
|---|---|---|
| immediate | `f() { … }` | nothing: the block runs inline, in the function's context |
| closure | `f() \|x\| { … }` | a closure to call |
| callback | `f() callback { … }` | a closure to call |
| **quote** | `f() quote \|x\| { … }` | **a tree to read** |

## 2. Syntax

```aether
f(args) quote |a: T, b: U| { body }     // parameters, a block
f(args) quote |a: T| -> expr            // parameters, one expression
f(args) quote { body }                  // no parameters
f(args) quote -> expr                   // no parameters, one expression
```

- **`quote` is contextual, not a keyword.** It means quoting only directly
  after a call's closing `)` and before `|`, `||`, `{` or `->`, on the same
  line as the `)` (the same-line rule the other forms keep). Everywhere else it
  is an ordinary name; `std/jsonpath/parser.ae:635` already has a variable
  called `quote`, and that stays legal.
- **Parameters should have types.** A closure parameter without one defaults
  to `int` (`typechecker.c:10417`). For a quote that would be a silent wrong
  guess, so an untyped quote parameter is an error.
- **The receiving function says it takes a tree.** Its last parameter is
  `quote.Tree`. Passing a quote to a function whose last parameter is not a
  `quote.Tree` is an error, and so is passing a `callback` or closure to one
  that is. That mirrors the existing check that rejects an immediate block
  for a function whose last parameter is `fn` (`typechecker.c:12591`).

## 3. What the tree looks like

The tree is a public type in a new standard module, `std.quote`. **Keeping it
stable is the main cost of the whole feature**, so it is kept small and close
to what any language with expressions has.

```aether
struct Tree {          // one per quote
    params: ptr        // list of Param: name, type
    body: *Node        // a Block
    captures: ptr      // list of Capture: name, type, cell (see 4)
    source: string     // file:line of the quote, for errors
}

struct Node {
    kind: int          // one of the kinds below
    type: string       // the Aether type the checker gave it: "float", "vec2", "int", ...
    name: string       // a local's, a parameter's or a capture's name; a called function's name; a field's name
    op: string         // "+", "<", "!", "&&", ...
    lit: string        // a literal's text, exactly as written
    kids: ptr          // list of *Node
    line: int
}
```

Kinds, version 1:

| Kind | Children | Meaning |
|---|---|---|
| `BLOCK` | statements | `{ … }` |
| `LET` | value | `t = …` binding a new local (`name`, `type`) |
| `ASSIGN` | target, value | assignment to an existing local |
| `RETURN` | value (or none) | `return …`, including the one `->` makes |
| `IF` | cond, then, else? | `if` statement |
| `WHILE` | cond, body | `while` |
| `FOR` | init, cond, step, body | C-style `for` |
| `BREAK`, `CONTINUE` | | |
| `EXPR` | expr | an expression statement |
| `LIT` | | `lit` holds `1`, `0.5`, `true`, `"text"`; `type` says which |
| `LOCAL` | | a local or a parameter, by `name` |
| `CAPTURE` | | an outer variable, by `name` (see 4) |
| `UNARY` | operand | `op` is `-`, `!` or `~` |
| `BINARY` | left, right | `op` is any binary operator |
| `CHOOSE` | cond, then, else | `if a { b } else { c }` used as a value |
| `CALL` | arguments | `name` is the function as written, plus its module (`math.sin`) |
| `FIELD` | object | `.x`, `name` holds the field |
| `INDEX` | object, index | `a[i]` |
| `MAKE` | field values | a struct literal, `Varyings { pos: p, uv: t }`; `type` is the struct, each child's `name` the field it sets |

**Every node carries the type the type-checker gave it.** A back end that
emits GLSL needs to know `t` is a `float` and `uv.x * 10.0` is a `float`; it
should never have to infer types again.

**A call is recorded, not made.** `sin(…)` in a quote becomes a `CALL` node
named `sin`. Nothing is called when the tree is built. The function still has
to exist and type-check, which is what makes a quote checkable at all: the
shader library declares `sin`, `vec4`, `texture`, `dot` and so on as ordinary
Aether functions. Those same functions double as the CPU evaluator's
implementation (section 6).

## 4. Captures

An outer variable used in the block becomes a `CAPTURE` node, and the tree's
`captures` list holds one entry per variable:

```aether
struct Capture { name: string, type: string, cell: ptr }
```

**`cell` points at the variable itself, not at a copy of its value.** The
compiler already moves a variable into a heap cell when a closure writes it
(`compute_promoted_captures`, `codegen_expr.c:3162`). A quote promotes every
variable it captures the same way, so the variable and the tree share the
cell. When the program changes `time`, the next read through the cell sees
the new value.

That is what makes uniforms automatic. A shader library walks `captures`,
declares a uniform for each, and each frame copies each cell's current value
into the uniform buffer. Nobody keeps a list of uniforms by hand.

`std.quote` reads a cell with typed getters (`quote.get_float(c)`,
`get_int`, `get_ptr`, …). A getter whose type does not match the capture's
`type` panics with both types named.

A capture of a function's own parameter works the same way: the parameter is
promoted to a cell for as long as the tree lives.

## 5. What a quote may contain, and the errors

The block is type-checked as an ordinary closure body. Then a second pass
rejects anything outside version 1's subset, each with an error that names the
construct, says why, and points at its line:

| Not allowed | Why |
|---|---|
| a closure, `callback` or immediate block inside | a tree of trees has no back end to go to |
| `defer`, `try`/`catch`, `panic` | control flow a shader, a query or an expression has no meaning for |
| actor sends, `spawn`, `receive`, `reply` | ditto |
| `match` | not in v1; it would need the pattern kinds in the tree. Later |
| string interpolation | v1 keeps `LIT` strings only. Later, as `CALL concat` |
| `new`, an array literal | v1 has no node for them. Later, when a back end needs them |
| taking a capture's address or writing a capture | the cell is shared with the program; a quote reads it |

Example error:

```
error[E07xx]: 'defer' can't be quoted
  --> sky.ae:14:9
14 |         defer cleanup()
   |         ^ a quote becomes a tree for a library to read; it has no 'defer' node
```

The subset can grow by adding kinds. That is the only way the tree changes:
**kinds are added, never removed or renumbered**, and `quote.VERSION` goes up
by one each time. A back end that meets a kind it does not know reports it
with the node's line.

## 6. ae3d's FXAA, written with `quote`

This is the body of `src/ae3d/vkspirv/glsl/fxaa_vk.frag`, which was GLSL
text when this was written (since step 4 it is `src/ae3d/shaders/fxaa`,
and both renderers draw it). The uniform block, the sampler and the `in`/`out` declarations
disappear. Uniforms are captures, the sampler is a captured texture, the
`in` is the parameter and the `out` is the return value.

```aether
import ae3d.gpu (Shader, fragment, vec2, vec3, vec4, Texture, texture, rgb, dot,
                  min, max, abs, clamp, smoothstep, sign)

fxaa(screen: Texture, texel: vec2, edge: float, edge_min: float, subpixel: float) -> Shader {
    return fragment("fxaa") quote |uv: vec2| {
        luma = vec3(0.299, 0.587, 0.114)
        c  = rgb(texture(screen, uv))
        n  = rgb(texture(screen, uv + vec2(0.0, -1.0) * texel))
        s  = rgb(texture(screen, uv + vec2(0.0, 1.0) * texel))
        e  = rgb(texture(screen, uv + vec2(1.0, 0.0) * texel))
        w  = rgb(texture(screen, uv + vec2(-1.0, 0.0) * texel))

        lc = dot(c, luma)
        ln = dot(n, luma)
        ls = dot(s, luma)
        le = dot(e, luma)
        lw = dot(w, luma)
        lo = min(lc, min(min(ln, ls), min(le, lw)))
        hi = max(lc, max(max(ln, ls), max(le, lw)))
        range = hi - lo
        if range < max(edge_min, hi * edge) {
            return vec4(c, 1.0)
        }

        avg = (ln + ls + le + lw) * 0.25
        blend = smoothstep(0.0, 1.0, clamp(abs(avg - lc) / range, 0.0, 1.0))
        blend = blend * blend * subpixel

        horiz = abs(-2.0 * lw + lc) + abs(-2.0 * lc + le) * 2.0 + abs(-2.0 * le + lc)
        vert  = abs(-2.0 * ln + lc) + abs(-2.0 * lc + ls) * 2.0 + abs(-2.0 * ls + lc)
        along = horiz >= vert
        g1 = (if along { ls } else { le }) - lc
        g2 = (if along { ln } else { lw }) - lc
        dir = if abs(g1) >= abs(g2) { sign(g1) } else { sign(g2) }
        step = blend * dir
        off = if along { vec2(0.0, step * texel.y) } else { vec2(step * texel.x, 0.0) }
        return vec4(rgb(texture(screen, uv + off)), 1.0)
    }
}
```

What this shows, and what it asks of the language:

- **It reads about as well as the GLSL**, and better than Option 1's
  `add(mul(…))` calls. The only real loss is swizzles: `.rgb` becomes
  `rgb(…)`.
- **`texel`, `edge`, `edge_min`, `subpixel` and `screen` are captures** of the
  function's parameters. The library makes them uniforms, and the sampler
  binding, without anyone writing a uniform block. ae3d's shared 300-field
  `SceneBlock` could be replaced shader by shader.
- **It needs vector types with arithmetic.** `uv + vec2(…) * texel` has to
  type-check. **Settled (2026-10-13, aether 0.809.0):** `vec2`, `vec3` and
  `vec4` are distinct types over the `f32x4` lane type. They keep its
  operators and `.x .y .z .w`, `vec4 * s` with a float variable is a `vec4`,
  and `vec3 + vec4` is a type error, so GLSL gets the right type names from
  the checker. Two compiler bugs stood in the way and are fixed
  (aether#2778, in 0.809.0): a scalar variable did not splat across a lane
  vector (only a literal did), and two different distinct types mixed in an
  operator were accepted. No new language feature was needed.
- **Matrices.** A `mat4` is a struct of four `vec4` columns in the shader
  library, with `*` as a library function (`mul(m, v)`) until Aether has
  operators on structs. Vertex shaders need it from the start (section 9).
- **`if` as an expression** covers GLSL's `?:` (`CHOOSE` in the tree).
- **An early `return`** inside the `if` is fine: it's a `RETURN` node, and
  GLSL keeps it as written.

## 7. How the compiler would do it

From mapping the compiler; nothing here is built yet.

- **Parser** (`parser/parser.c`, trailing-block dispatch at 2405-2491): a
  `quote` identifier, contextual, on the same line as the call's `)`, followed
  by `|`, `||`, `{` or `->`. It reuses `parse_closure_expression` for the
  parameters and body.
- **A new node type, `AST_QUOTE`**, appended at the end of the enum in
  `ast.h`. Not an `AST_CLOSURE` with a marker: about 60 places in codegen
  special-case `AST_CLOSURE` values (`"trailing"`), and closure discovery
  would try to hoist it. A node of its own touches none of them.
- **Type-checking** reuses the closure case (`typechecker.c:10396`): a child
  scope, the parameters registered with their annotated types, the body
  checked as statements. Then the subset pass (section 5) and the
  `quote.Tree` parameter check.
- **Captures** come from the same free-variable discovery closures use
  (`discover_closures_scoped`, `codegen_expr.c:2716`), and each is promoted
  to a cell as `compute_promoted_captures` already does for written
  captures.
- **Codegen** emits, per quote, a static C function
  `_quote_build_N(cells…)` that calls `std.quote`'s C runtime
  (`aether_quote_node(kind, type, name, op, lit, line)`,
  `aether_quote_add(parent, child)`, …) to build the tree, and a call to it
  where the quote stands. Parts of the tree without captures are the same
  every time, so they can be built once and shared.
- **`@derive(schema)`** (`codegen_schema.c`) is the nearest thing the
  compiler already does: it turns syntax into a table the program reads at
  runtime. Its shape is the model for the emitted builder.
- **A hash for each tree.** The builder can also emit a hash of the quote's
  source and tree, as a constant, so a back end can cache what it made
  (GLSL, SPIR-V, native code) under it plus a hash of the back end itself.
  That is how ChrysaLisp keeps its shader output now: it never rebuilds an
  unchanged shader, and it never serves output from an older back end.

## 8. Beyond shaders

- **Test failures that show the expression.**
  `expect() quote -> a + b == c` lets the library print
  `a + b == c failed: a + b is 7, c is 8`, because it can evaluate each side
  of the `BINARY` node.
- **Query builders.** `where() quote |p: Person| -> p.age > 30` becomes
  `WHERE age > 30`, as LINQ does.
- **Numeric functions, not shaders.** A quote with arguments and no pixel,
  such as a matrix product or a physics step, can go to the CPU evaluator,
  to C, or later to GPU compute. ChrysaLisp has just done this ("functions
  for Lisp to call": the shader language with arguments in place of a
  pixel, as fast as hand-written native code), and plans GPU compute next.
- **Symbolic maths and autodiff**, by walking and rewriting the tree.
- **aether-ui's** reactive bindings could see which state a computed value
  reads, instead of being told.

## 9. Order of work

1. **Option 1 first, as a plain ae3d module** (`ae3d.gpu`): the node types
   (the same `std.quote` shapes, built by hand for now), a GLSL emitter and a
   CPU evaluator. Prove it on FXAA: the emitted GLSL compiles with
   `glslangValidator` to the same SPIR-V as `fxaa_vk.frag`, and the CPU
   evaluator matches the GPU within a tolerance on a test image. This needs
   no compiler change and settles the node kinds against a real shader.
   *Done (ae3d main, 31736783, 2026-10-13):* `ae3d.gpu` and
   `tests/test_gpu.ae`. The GLSL it writes for FXAA reads as the hand-written
   one, compiles with glslang and passes spirv-val (it is not the same SPIR-V
   as `fxaa_vk.frag`, which reads its uniforms from the shared `SceneBlock`;
   this one has a block of its own). The CPU evaluator agrees with FXAA
   written straight in Aether, with the new vector types, to 2.4e-8 on every
   pixel of a test image. *And against the GPU (d778da25):* over a frame the
   renderer drew, the evaluator's FXAA is within one step of 255 of what
   `fxaa_vk.frag` made on the GPU on every channel of every pixel, on an
   Apple GPU and on lavapipe (x86_64 and arm64). Step 1 is closed.
2. ~~**Settle the vector-type question** (section 6), in aether.~~ Done:
   distinct types over `f32x4`, after aether#2778 (0.809.0).
3. ~~**`std.quote` and `AST_QUOTE` in aether**, expressions first, then
   statements, then captures.~~ Done: aether#2819, merged 2026-10-13, after
   0.809.0. The authoritative description is now `aether/docs/quote.md`;
   this doc is the history. Where it departs from sections 3 to 5 above:
   `Tree`, `Node` and `Capture` are opaque handles read through accessors;
   a struct literal's fields are `FIELD_VALUE` nodes; a program-level `var`
   is a capture at its own address; the errors are E0800 to E0803; and
   `quote` stayed contextual because the module is itself named `quote`.
4. **FXAA through the real `quote`**, replacing the hand-built tree from step
   1, and then one shader at a time, retiring the duplicated GL and `_vk`
   GLSL as each moves.
   *FXAA done (ae3d main, 2026-10-13, on Aether 0.810.0):*
   - `ae3d.shaders.fxaa` is FXAA in Aether: `fxaa(screen, texel, edge,
     edge_min, subpixel)` returns `fragment("fxaa") quote | uv: vec2 | {...}`,
     type-checked against `ae3d.shaderlib` (vec2/vec3/vec4 distinct over
     f32x4, `Texture`, GLSL's builtins as Aether functions whose bodies are
     what each means; `rgb(c)` stands for `c.rgb`).
   - `ae3d.gpu` walks the `quote.Tree`; `GpuNode` is gone. It writes GLSL in
     two dialects (`gpu.VULKAN`, `gpu.GL` for desktop 4.1), the full-screen
     vertex shader for each, the captures' std140 block (`params_*`) and
     fills it from their cells (`params_write`); its CPU evaluator reads the
     captures from their cells and rounds to f32 as a GPU does.
   - `tools/generate_shaders.ae` compiles the quoted shaders' Vulkan GLSL into
     `ae3d.vkspirv` beside the others, holds the `Params` offsets to
     glslang's, and records `quote.hash` of each tree (`FXAA_QUOTED_HASH`);
     `--check` fails on a stale GLSL text or a tree whose hash moved.
   - Vulkan: `ae3d.vkquote` draws a quoted full-screen pass with a set of its
     own (the block at 0, the texture at 1, a mapped block per frame slot,
     filled from the cells before each draw) and refuses a tree whose hash
     is not the SPIR-V's. OpenGL compiles the same tree's GL GLSL at start
     and sets its uniforms by name. Both make the tree again when the frame
     changes size (the texel is a capture). `fxaa_vk.frag` and the GL
     `FRAGMENT_FXAA` heredoc are deleted, and FXAA's three floats left the
     scene block.
   - Proof: `tests/test_gpu.ae` (golden GLSL for both dialects, glslang and
     spirv-val, the block's layout, the evaluator against FXAA in Aether)
     and `tests/test_gpu_fxaa.ae` (the evaluator against both renderers'
     GPU FXAA, at two frame sizes, within one step of 255, two on Apple's
     OpenGL over Metal); `test_backend_parity`'s fxaa comparison is
     unchanged to the channel.

   *Since then (ae3d #792, Aether 0.817.0, quote version 2):* the bloom's
   down and up passes and the one-sample `depth_copy` are quoted too, the
   bloom's helpers as `@quotable` functions. The bloom's `_vk` files and GL
   heredocs are gone, and `depth_copy_vk.frag` went once its one-sample
   frames matched main's (M6, 2026-10-16). After that, on
   `wip/quote-depth-resolve`: `depth_resolve` (TextureMS, a sampler2DMS),
   `color_resolve`, `taa` and `ssao`, the last bringing `mat4` and calls each
   dialect writes its own way (`depth_clip`, `screen_y_sign`).

   *The rest, one at a time, in this order* (Nic, 2026-10-16; see
   `aether_quote_questions_for_nic.md`), each adding to `ae3d.gpu` and
   `ae3d.shaderlib` what it is the first to need, and deleting its `_vk`
   file and its GL heredoc in the commit that moves it, as FXAA's did:
   - **`depth_resolve`**, the multisampled depth copy: a multisample
     texture type (`sampler2DMS`, `texelFetch` with a sample index).
   - **`color_resolve`, `ssr`, `ssao`, `taa`**, one commit each.
   - **the sky's light**: `sky_filter` and `sky_irradiance`, screen passes
     over the capture's mips (`texture_lod`, `texel_fetch_lod`). The sky
     itself, its capture and its clouds (`sky`, `sky_capture`, `cloud`) move
     to step 6 (Paul, 2026-10-16): each takes a direction and two clip
     positions from its own vertex shader and writes a colour and a motion
     vector, and reads `sampler3D`s.
   - **3A, module-scoped structs**, in aether (question 3 of the questions
     doc), before the vertex shaders.
   - **the passthrough**, `screen_vk.vert` / `VERTEX_SCREEN`, which every
     post pass draws with: `gpu.emit_screen_vertex` already writes it for
     each quoted pass, and the hand-written one goes when the last pass
     reading it has moved. *Gone (2026-10-18) with the hand-written
     composite, the last pass that read it.*

   **The composite** (two textures, `hazeColumn[4]`, `hazeShape[4]` and a
   `mat4`) and **the sky, its capture and its clouds** (varyings from their
   own vertex shader, two outputs, `sampler3D`) move with the vertex shaders
   in step 6, and so do the mesh
   shaders (scene, water, crowd): their vertex stage is a quote too, and
   their uniforms are the scene block.
5. **MSL**, after step 6 (the vertex shaders) (Nic, 2026-10-16; the FXAA-only MSL
   spike is dropped). A SPIR-V writer of our own is on hold until something
   needs it (Nic, 2026-10-19): glslang stays the precompiler, turning the
   GLSL ae3d.gpu writes into the SPIR-V ae3d.vkspirv holds, and with
   `spirv-val` it stays CI's checker (`generate_shaders --check`). Chris's
   `spirv.inc` and the SPIR-V spec are where that writer would start.
   *The MSL written (2026-10-20, on Aether 0.834.0); no Metal renderer yet:*
   ae3d.gpu has a third dialect, `gpu.METAL` (`emit_msl`, `emit_vertex_msl`,
   `emit_screen_vertex_msl`), written from the same trees as the GLSL, and
   the generator writes every quoted shader's MSL into `src/ae3d/metal`
   (41 files), which `--check` holds current byte for byte as it holds the
   GLSL. `scripts/msl_check.sh` (in `./ci.sh` on macOS) compiles them with
   Metal's compiler with every warning an error; each block struct's std140
   offsets are `static_assert`s in the text, so the compiler holds the MSL's
   layout to the block the renderer fills. Section 11, "What it buys MSL",
   has the rules and the choices left for a Metal path. No aether change
   was needed: quote's trees carry everything the dialect reads.
6. **Vertex shaders.** ChrysaLisp's split is worth taking as an idea: a
   vertex shader's inputs and outputs are declared, and one vertex shader
   serves any pixel shader whose inputs it provides. For us the vertex
   quote's return type is a struct of varyings, built with a struct literal
   (`MAKE`, which is why v1 has one), and the pixel quote takes it as its
   parameter. The composite moves with them, and so do the sky, its capture
   and its clouds. Designed in section 11.

## 10. Open questions for Nic

Nic said "go for it" on 2026-10-10. These are the questions still open; the
vector-type one is settled (section 6).

- **Is `quote.Tree`'s public shape stable enough to commit to?** It is the
  feature's long-term cost. Versioned and additive-only is the proposal.
- **Build time instead of start-up?** Running the library at compile time
  (as a Lisp macro does) would mean running Aether inside `aetherc`. Not
  proposed now, but the tree format should not rule it out.
- **Should a quote be allowed outside the trailing position**, as a value
  (`q = quote |x: float| -> x * 2.0`)? It costs little once the trailing form
  exists, and the test-failure use (section 8) wants it.

## 11. Step 6, designed: vertex shaders, varyings, the scene block

Design only; nothing here is built. Written 2026-10-16 after step 4's
post-process passes moved (`wip/quote-depth-resolve`), assuming 3A
(module-scoped structs, aether#2939): each shader module declares its own
`Vertex`, `Varyings` and outputs, and two modules' `Varyings` are two types.

### What Aether already gives it

Probed on 0.817.0, so none of this needs a quote version bump:

- **A struct parameter and a struct literal returned**: `quote | v: V | ->
  V { p: v.q, q: v.p * 2.0 }` is `(param v :V)` and `(RETURN :V (MAKE :V
  (FIELD_VALUE p ...) ...))`, every `FIELD` typed.
- **A captured struct holding a fixed-size array, indexed by a local**:
  `g_haze.columns[i]` is `(INDEX :float (FIELD columns :float[4] (CAPTURE
  g_haze :Haze)) (LOCAL i :int))`.

**A shader module's last name must be no other ae3d module's.** A
program importing two modules called `sky` (`ae3d.sky`, and a shader module
`ae3d.shaders.sky`) had aetherc prefix one module's functions, and the
prefixed names went into the quote tree's helpers, so the tree's hash, and
the SPIR-V it keys, depended on what else the program imported: the engine's
programs refused the sky's passes (M6, 2026-10-16). The shader module is
`ae3d.shaders.skyprobe`; aether is to make a helper's name in a tree
independent of the program, and until a release has that, the names stay
apart.

Still outside the subset (E0800), and designed around rather than asked
for: array literals, casts (`float(i)` -- loops count in floats, as
step 4's do), `out` parameters (a helper returns a struct instead).

### The shapes

```aether
// ae3d.shaders.skydome
struct Vertex { position: vec3 }
struct Varyings {
    position: vec4      // the clip position: gl_Position, not an output
    dir: vec3
    clip_now: vec4
    clip_prev: vec4
}
struct SkyOut { colour: vec4, velocity: vec2 }

sky_vertex(view_projection: mat4, prev_view_projection: mat4) -> *GpuShader {
    return gpu.vertex("sky") quote | v: Vertex | {
        pos = mul(view_projection, vec4(v.position, 1.0))
        // pos.xyww: the sky at the far plane, whatever its distance.
        return Varyings { position: vec4(vec3(pos.x, pos.y, pos.w), pos.w), dir: v.position,
                          clip_now: pos, clip_prev: mul(prev_view_projection, vec4(v.position, 0.0)) }
    }
}
sky(...) -> *GpuShader {
    return gpu.fragment_of("sky", SkyOut) quote | f: Varyings | { ... return SkyOut { colour: c, velocity: m } }
}
```

- **The vertex quote** (`gpu.vertex`) takes one struct, its vertex
  attributes, and returns a struct of varyings built with `MAKE`. A field
  named `position` is `gl_Position` (vec4); every other field is an `out`
  at the location of its place among them, `flat` when it is an int or a
  bool (GLSL does not interpolate those).
- **The pixel quote** takes a struct of varyings. Its fields are matched to
  a vertex shader's **by name and type**, not by struct identity: one
  vertex shader serves any pixel shader whose inputs it provides (the
  ChrysaLisp split). The pixel shader declares only the varyings it reads,
  at the vertex shader's locations. `gpu.link(vertex, pixel)` checks the
  pair (a missing or mistyped field is refused, naming it) and gives the
  locations; a pipeline is built from a linked pair.
- **Outputs**: a pixel quote returning a vec4 is `FragColor`, as today. One
  returning a struct writes each field to the `out` at its place
  (`layout(location = k)`): the sky's colour at 0 and motion vector at 1,
  as `FragColor` and `outVelocity` are now. A depth shader stays a float.
- **Vertex attributes** are not numbered by field order: the pipelines'
  vertex input state is fixed (position 0, uv 1, normal 2, `instanceModel`
  3..6, `instanceColor` 7, joints 8, weights 9, occlusion 10,
  `instancePhase` 11, mask uv 12, `instanceExtras` 13). `ae3d.gpu` keeps one
  table of attribute names to locations, as it keeps one table of calls
  (Nic's option A again); a `Vertex` field not in it is refused. A mat4
  attribute takes four locations.
- **Structs inside the tree** (a helper's struct return, a struct local) are
  written as GLSL `struct` declarations, named as helpers are
  (`sky_CloudSample`), so `out` parameters become struct returns:
  `cloudDensity(..., out float heightFraction)` returns
  `CloudSample { density, height }`.

### What the back ends grow

1. **Struct values on the CPU.** The evaluator's values are up to four
   lanes; a struct value becomes a list of named field values (a vec4, a
   float, a mat4 cell). `cpu_run` of a vertex shader takes the attribute
   struct and returns the varyings struct; of a pixel shader, takes a
   varyings struct and returns its colour or output struct. The CPU does
   not rasterise: a test feeds the pixel stage the varyings it chooses, and
   holds each stage to the same stage written as plain Aether, as step 4's
   tests do.
2. **Captured arrays and structs in the block** (built with the
   composite's haze, 2026-10-18). std140 as glslang has it:
   an array's stride rounded up to 16 (`float waveAmplitudes[4]` is 64
   bytes, not 16), a struct aligned to 16 and its size rounded to 16. The
   cell's layout is Aether's (`float[4]` is four packed f32s), so
   `params_write` repacks element by element; the generator already holds
   every offset to glslang's.
   *An array of structs (2026-10-20, on Aether 0.834.0)*, the scene's
   `lights: Light[16]`: `gpu.capture_field` places the array and
   `gpu.capture_element_field(s, "world", "lights", sizeof(Light),
   "colour", offsetof(Light, colour))` each field of its element. The
   element is a GLSL struct of its own, declared once before the struct
   holding the array, with every field the tree reads of a value of that
   type or sets in a literal of it, in the cell's order: an element is
   handed to a helper whole (`direct_light(world.lights[i], ...)`), and a
   literal of the type (`clustered_light`'s) is the same struct. std140
   aligns it to sixteen and rounds its size up to sixteen, its arrayStride;
   OpenGL sets it a value at a time (`world.lights[3].colour`); the
   generator holds each element to glslang's topLevelArrayStride
   (tests/test_gpu_struct_arrays).
3. **`Texture3D`** (`sampler3D`), read by `texture_3d(t, p)`; on the CPU a
   `ShaderImage3D`, trilinear across its slices.
4. **`emit_glsl` of a vertex shader**, both dialects; `emit_screen_vertex`
   becomes the first vertex quote (below).

### Order, one commit and one GPU run each

1. **The screen vertex shader** as a vertex quote: `Vertex { position:
   vec3, uv: vec2 }` to `Varyings { position, uv }`. Every quoted pass
   already uses a generated screen vertex shader; this one replaces
   `gpu.emit_screen_vertex`, and with it `VERTEX_SCREEN` and
   `screen_vk.vert` once no hand-written pass uses them (the passthrough
   step 4 left).
2. **The sky family**: `sky_vk.vert` as `sky_vertex`, then `sky`,
   `sky_capture` and `cloud` (one source today, three variants: three quote
   functions sharing `@quotable` helpers). New with them: struct outputs
   (colour and motion), `Texture3D`, struct-returning helpers. About 670
   lines of GLSL; the clouds' march is most of it.
   *Done (2026-10-17, on Aether 0.822.0):* `ae3d.shaders.skydome`, drawn on
   both renderers with frames byte-identical to the hand-written ones (the
   clouds within #793's noise). On Vulkan the sky is a linked pair
   (`vkquote.pair_new`, the vertex shader's block at set 1); its values are
   copied word for word, from the scene block and, for those only the sky
   read, from `vkframe`'s sky words; the hand-written sky family is gone. The
   capture needed an octahedral decode a vector at a time, as the
   hand-written one is: skyprobe's, a lane at a time, rounded a few
   directions otherwise on MoltenVK.
3. **The composite**: two textures, `mat4`, and `hazeColumn[4]` /
   `hazeShape[4]` as a captured struct with array fields.
   *Done (2026-10-18, on Aether 0.824.0), without the struct:*
   `ae3d.shaders.composite`, drawn on both renderers with frames
   byte-identical to the hand-written one's. The columns are eight `vec4`
   captures, and the haze's loop picks its column with a `@quotable`
   `haze_column(k, c0, c1, c2, c3)`, keeping the hand-written loop's break,
   continues and `float(k)`. A captured struct with array fields hit two
   gaps. First, quote 0.824.0 types a captured struct's `vec4[4]` field as
   `UNKNOWN[4]`: `quote_type_name` spells an array through
   `type_to_string`, which has no name for a distinct vector type. Second,
   a back end cannot read a captured struct's cell without its layout,
   which a tree does not carry. `haze_screen`'s `out float w` is a
   `HazePoint` it returns. Its cleanup removed four things. The first two
   are the hand-written composite and `VERTEX_SCREEN` / `screen_vk.vert`,
   the composite being the last pass that drew with them. The third is
   `vkpipes`' post pipelines. The last is the six scene-block uniforms only
   the composite read: frameExposure, enableBloom, bloomIntensity,
   hazeCount, hazeColumn and hazeShape. The block now has 177 uniforms and
   15808 bytes. Those values are now `vkframe`'s composite words.
   *With the struct (2026-10-18, on Aether 0.829.0):* the haze is one
   captured `Haze { count: int, column: vec4[4], shape: vec4[4] }`, and the
   loop reads `haze.column[kk]` and `haze.shape[kk]`; `haze_column` is
   gone. aether#2972 (0.829.0) types the field `vec4[4]`. The layout the
   tree does not carry comes from the shader's module, with the compiler's
   own offsets: `gpu.capture_field(s, "haze", "column", offsetof(Haze,
   column))`. ae3d.gpu declares the GLSL struct with the fields the body
   reads, in the cell's order. `params_write` repacks each element from
   the cell to std140's 16-byte stride. A `float[4]` is doubles 8 bytes
   apart in the cell, and 16 apart in the block. The CPU reads an element
   from the cell. OpenGL sets the struct a value at a time
   (`gpu.uniforms_*`: `haze.column[2]`). A field read but not placed is
   refused. The frames are byte-identical to the eight captures'.
4. **Water**, then **the crowd**, then **the scene**: the mesh shaders, and
   with them the scene block.
   *Water done (2026-10-19, on Aether 0.829.0):* `ae3d.shaders.sea`, a
   vertex and a pixel quote drawn on both renderers with frames
   byte-identical to the hand-written ones. `Light[16]` was probed first:
   quote 0.829.0 types it `Light[16]`, its element `Light` and a field of
   one `vec4` (and `mat4[96]` likewise), so the scene's lights need nothing
   of aether. What the water reads is four captured structs: the frame's
   `Eye`, `KeyLight` and `Weather` (`ae3d.shaders.frame`; the camera's is
   `Eye` because `Camera` is `ae3d.core`'s, and an engine module importing
   both could no longer name its own unqualified), and the draw's `Water`.
   A `mat4` is a field of a captured struct now. Each field is the scene
   block uniform it was, and both renderers fill the structs from what
   filled those uniforms: Vulkan copies the water program's block word for
   word (`gpu.set_field_words`), OpenGL from the renderer's state and the
   model's uniforms by name. On Vulkan the pair is drawn per draw through
   `vkquote`'s ring (`mesh_pair_new`: opaque, culled and blended pipelines
   on its layout), every struct in each draw's block for now; the scene
   shader's draws are where the frame's structs want a binding of their
   own. Three things the hand-written shape decided:
   - a vertex shader's captures are named apart from its pixel shader's
     (`surface`, `viewer`; `water`, `eye`): on OpenGL a uniform of one name
     is one uniform across the program, and the two read other fields
     (`gpu.link` refuses a struct both capture under one name);
   - the vertex shader still hands on the uv and the trains' normal, which
     no pixel shader reads, at the hand-written places;
   - a helper the hand-written shader wrote reading its uniforms is written
     where it is used when a helper given them as arguments rounds
     otherwise: `water_below`, given the inverse view-projection as an
     argument, put the shore's sums a step out in 117 channels on MoltenVK,
     whose fast math orders a sum by where its values were loaded. waveField
     is written into the pixel shader's body (a shader cannot hand a helper
     the wave table), and its `out` parameters with it.
   Its cleanup removed `VERTEX_WATER`, `FRAGMENT_WATER`, `water_vk.*` and
   `vkpipes`' water pipelines; the water's shader is a kind with no source.
   With them went the 34 scene-block uniforms only they read (143 uniforms,
   15216 bytes): Vulkan keeps their words where the pair copies them from,
   the overcast in `vkframe`'s sky words, the rest in the water's own
   (`vkframe.water_word`).
   *The crowd done (2026-10-19, on Aether 0.830.0):* `ae3d.shaders.throng`,
   its three vertex shaders (`crowd_vertex`, `crowd_pull_vertex`,
   `crowd_depth_vertex`) drawn with the scene's and the depth pass's
   hand-written pixel shaders, which move with the scene. The frames are
   byte-identical to the hand-written crowd's on both renderers (zombie_city
   within #794). What they read is the draw's `Throng` and the frame's `Eye`
   and `Shadow` (the map's light space, a lamp's reach); their varyings are
   named as FRAGMENT_DEFAULT's and FRAGMENT_DEPTH's inputs, at their places.
   A vertex shader now samples textures (the pose bank) and reads storage
   buffers (`Floats`, `Vec4s`: the cluster cut's vertices, skin and
   figures, at set 1, the shader's own set then 2). On Vulkan a quoted
   vertex shader with a hand-written pixel shader is a vertex ring
   (`vkquote.vertex_ring_new`): the scene's set, then its own, a dynamic
   uniform buffer of each draw's values copied word for word from the block
   the scene's ring took for it. The skinning is written a matrix at a time
   (`mul_fm4`, `add_m4`, `mul_m4f`), in the hand-written order; the
   optimised SPIR-V's arithmetic is the hand-written one's op for op, but
   for where a component is extracted.
   Its cleanup removed `VERTEX_CROWD`, `VERTEX_CROWD_DEPTH`, `crowd_vk.vert`,
   `crowd_pull_vk.vert`, `crowd_depth_vk.vert` and `vkpipes`' crowd
   pipelines, and with them the nine scene-block uniforms only they read
   (134 uniforms, 15168 bytes): Vulkan keeps their words in the crowd's own
   (`vkframe.set_crowd_*`), where the rings copy them from.
   *The scene done (2026-10-20, on Aether 0.834.0):* `ae3d.shaders.lit`,
   the scene's vertex shaders (`lit_vertex`, and `lit_plain_vertex` for
   the plain pipelines, which name no skin stream), its pixel shader
   (`lit_pixel`, FRAGMENT_DEFAULT's) and the depth pass's
   (`lit_depth_vertex`, `lit_depth_plain_vertex`, `lit_depth_pixel`,
   FRAGMENT_DEPTH's), drawn on both renderers, the crowd's vertex shaders
   with them. At one sample every parity frame is byte-identical to the
   hand-written scene's on both renderers but the clouds (#793). What they
   read is the scene's three blocks (below), each a `gpu.use_layout` of
   whole structs, so one layout places a field for the hand-written
   shaders, the quoted ones and the renderer's staging alike; the images
   and buffers are at the hand-written bindings (`gpu.capture_binding`).
   On OpenGL each struct is a uniform (`eye`, `world`, ...) and the
   renderer still sets each value by its hand-written name: the scene's
   programs find it by the name the quoted shaders give it (`lit.gl_name`:
   viewPos is `eye.position`, `lights[2].color` `world.lights[2].colour`).
   The crowd's vertex shaders capture the frame's Eye as `viewer` now: the
   pixel shader they are drawn with captures the whole camera as `eye`,
   and on OpenGL one name is one uniform across the program. Each helper is
   the hand-written one's shape, and reads its uniforms in place
   (`gpu.read_in_place`), MoltenVK's fast math rounding by where a value
   was loaded. The ray-query pixel shader (`scene_rq_vk.frag`) was the
   hand-written one until step 6b (below): no device here traces rays, so
   only CI's lavapipe could hold a quoted one to it.
   Its cleanup removed `VERTEX_DEFAULT`, `VERTEX_DEPTH`, `FRAGMENT_DEPTH`,
   `shaders.default_shader` (a model without a shader is drawn by the
   scene's), `scene_vk.vert`, `scene_plain_vk.vert`, `scene_vk.frag` and
   the three `depth_*vk.*`. `FRAGMENT_DEFAULT` stayed as the ray-query
   shader's source alone (step 6b removed it), and the generator lays the three blocks out from
   their tables, no longer from the hand-written declarations. No scene
   block uniform went with them: each of the 134 is read by a quoted
   shader, by the ray-query one (the rays, the probes) or copied by the
   water's (`viewDistance`), so the blocks are the size they were.

### The scene block

Split (Nic, 2026-10-20: "option 1"): the scene's one block is three, each
in a descriptor set of its own on Vulkan, and still one camera, so every
frame is the one it was. The flat blocks keep their members in the order
of the structs (`frame.view_layout`, `frame.world_layout`,
`lit.draw_layout`; std140 places a flat block as it does the structs, which
glslang's placement of each member checks), so the hand-written shaders and
the quoted ones read one staging layout.

| Set | Block (bytes) | Structs | What is in it |
|---|---|---|---|
| 0, the draw's | 13,056, a dynamic offset a draw | `Draw`, `DrawMaterial`, `Surface`, `Cut`, `Wounds`, `Damage`, `Skin` (`ae3d.shaders.lit`) | the model and last frame's, the key light's map space, instancing, the material and surface, the cut, wounds, damage, bones; the colour, normal, scene-depth and damage textures |
| 1, the camera's | 800 | `Eye`, `ShadowCascades`, `Grid`, `Probes` (`ae3d.shaders.frame`) | everything that depends on the view; the shadow atlas, the cluster lights and words, the lamps' atlas, the occlusion map, the probes' atlases |
| 2, the world's | 1,424 | `WorldState` (with `lights: WorldLight[16]`), `Weather` | what every view sees alike; the sky light, the BRDF table, the sky's irradiance, the rays' structure |

Each uniform, by block (the hand-written name, then the field):

| Camera (set 1) | |
|---|---|
| `viewProjection`, `prevViewProjection`, `invViewProjection` | `eye.view_projection`, `.prev_view_projection`, `.inv_view_projection` |
| `viewPos`, `viewDistance`, `jitter`, `screenSize` | `eye.position`, `.far`, `.jitter`, `.screen_size` |
| `hasSceneDepth`, `viewDepth`, `occlusionHistory` | `eye.depth_on`, `.depth_plane`, `.history` |
| `captureChannel`, `rayReach`, `rayFrame` | `eye.capture`, `.ray_reach`, `.ray_frame` |
| `hasShadowMap`, `cascadeMatrices`, `cascadeSplits`, `cascadeTexelWorld`, `cascadeCount` | `cascades.on`, `.matrices`, `.splits`, `.texel_world`, `.count` |
| `clusterDims`, `clusterDepth`, `clusterViewProjection`, `lampShadowBase`, `keyLampSlot` | `grid.dims`, `.depth`, `.view_projection`, `.lamp_base`, `.key_lamp` |
| `ddgiOn`, `ddgiDims`, `ddgiBase`, `ddgiSpacing`, `ddgiAtlas` | `probes.on`, `.dims`, `.base`, `.spacing`, `.atlas` |

| World (set 2) | |
|---|---|
| `lights[16]`, `lightCount`, `shadowDirection` | `world.lights` (`WorldLight`: position, colour, intensity, temperature, kind, direction, constant, linear, quadratic, cos_outer, cos_inner), `.light_count`, `.shadow_direction` |
| `cloudCover`, `cloudTime`, `cloudSun`, `causticsTime`, `wetness` | `world.cloud_cover`, `.cloud_time`, `.cloud_sun`, `.time`, `.wetness` |
| `normalStrength`, `occlusionStrength`, `giOff`, `rayShadows`, `sunAngle`, `rayOcclusion`, `rayOcclusionStrength`, `rayLampRadius` | `world.normal_strength`, `.occlusion_strength`, `.gi_off`, `.rays`, `.sun_angle`, `.ray_occlusion`, `.ray_occlusion_strength`, `.ray_lamp_radius` |
| `enableFog`, `fogStart`, `fogEnd`, `fogRadiance`, `fogIntensity` | `weather.fog`, `.fog_start`, `.fog_end`, `.fog_radiance`, `.fog_intensity` |

The other 86 uniforms are the draw's: `lightSpaceMatrix` and the
volumetric settings too, since models write them per draw.

**A second camera is a second camera set.** `vkdesc.frame_sets` writes the
frame's camera block and its images into set 1 and the world's into set 2,
once a frame, before the first draw binds them (`vkframe.frame_sets_now`).
Another camera needs only its own set 1 (a block filled the same way, from
its own view) bound in the first one's place for its draws; the world's set
and every draw's set stay as they are. Nothing else in a shader, a pipeline
or a layout changes: the pipelines are made on the three set layouts
(`vkpipes.scene_layouts`), and a shader drawn beside the scene takes its
own sets after them (`frame.SCENE_SETS`, the crowd's rings at 3).
A second camera is drawn now (#866): a view is a frame of its own, in the
frame slot it is drawn in, so its camera block and images are that slot's set
1 and the world's set 2 is the slot's too, with nothing in a shader, a
pipeline or a layout changed; `docs/rendering.md`, "Views", has what it keeps
apart (its images, its temporal history, its cascades' and lamps' atlases,
its clusters, its exposure) and what it shares (the scene). The pick pass
(#865) takes the same three sets: its shaders are quoted over the same
blocks (`ae3d.shaders.lit`'s `pick_vertex`, `pick_plain_vertex`,
`pick_pixel`, with `Draw.pick` the model's id), so a picked frame's pick draws
are the scene's, bound as the scene's are.

### Step 6b: the ray-query pixel shader (2026-10-26)

The last hand-written scene shader, `scene_rq_vk.frag` (FRAGMENT_DEFAULT
built with `AE3D_RAY_QUERY`), is `lit_rq_pixel` now, and both are gone.

- **ae3d.gpu grew ray queries.** `AccelerationStructure` is
  `accelerationStructureEXT`, captured and placed with `capture_binding`
  (set 2, binding 4); `RayQuery` is `rayQueryEXT`, declared by
  `q = ray_query()` and not given a value; `ray_query_initialize`,
  `ray_query_proceed`, `ray_query_committed_hit` and the two flag constants
  are the GLSL calls. A shader that traces is GLSL 4.60 with
  `GL_EXT_ray_query`, and OpenGL's emission is refused. In MSL the structure
  is an `instance_acceleration_structure` among the pixel shader's buffers
  and a query an `intersection_query<triangle_data, instancing>` with the
  flags as `intersection_params`. The CPU's evaluator has no scene: a ray finds
  nothing. No aether change was needed.
- **`lit_rq_pixel` is `lit_pixel`'s body with four additions**, in the order the
  hand-written shader had them: the sun's shadow by four rays on a spiral
  (`ray_shadow_factor`), a lamp's by one ray to a spot on its face
  (`ray_lamp_factor`), the sky's occlusion by four rays over the hemisphere
  (`ray_occlusion_factor`), and the probes' irradiance (`ddgi_irradiance`:
  two cascades, trilinear over eight probes, each weighed by facing and by
  Chebyshev visibility, a grid cell three ints for GLSL's `ivec3`, written
  out an axis at a time). It is a copy of lit_pixel's body, not a
  specialisation of it, so that `lit_pixel` and the 59 frames every device
  without ray queries draws stay as they are (their GLSL, SPIR-V and
  hashes are unchanged); `tests/test_gpu_lit_rq` is what keeps the copy
  honest: on the CPU, where no ray finds anything and no probe is on, the two
  shaders must shade 12 cases (rays and probes off and on, a key light, a lamp,
  the sky) to the same lane, exactly. Four negative controls each fail it (the
  body's exposure, the sun's factor, the lamps', the probes' fall-back).
- **Where it is drawn.** `vkpipes` and `vkframe`'s crowd rings use
  `LIT_RQ_QUOTED_FRAG` where the device traces, with the scene's vertex
  shaders; its tree's hash is checked at start as the others'. Its bindings
  are the hand-written one's (set 2 binding 4; set 1 bindings 6, 7 and 8).
- **Held.** glslang for Vulkan 1.2 and `spirv-val` take its SPIR-V; its MSL
  passes the device compiler and `xcrun metal` (MoltenVK takes no ray query,
  so that is as far as the M6 goes: MSL ray queries are compile-checked
  only). Only a device that traces draws it: CI's lavapipe (test_ray_shadows,
  test_ray_occlusion, test_gi); the verification is recorded in
  project_quote_shader_work.
- **The cleanup** removed FRAGMENT_DEFAULT and, with it, 560 lines of
  generator that read hand-written GLSL: the three blocks' uniforms are typed
  by their tables alone, and `ae3d.vkscene` is byte for byte what it was.

### What it buys MSL (step 5, after this)

MSL comes after the mesh shaders (Nic, 2026-10-19). Our own SPIR-V writer
is on hold until something needs it; glslang stays the precompiler and,
with `spirv-val`, CI's checker (section 9, item 5).

Metal's stage-in and stage-out are structs (`[[stage_in]]`, a returned
struct with `[[position]]`), so varyings designed as structs map across as
they are. The attribute table becomes `[[attribute(n)]]`, and the block's
structs Metal's argument buffers.

*Written (2026-10-20, on Aether 0.834.0):* `gpu.METAL`, the expressions and
statements the GLSL emitter's, in a third column of the call table
(`CALL_MSL`: `t.sample(ae_smp_t, uv)` for `texture`, `.read()` for the
fetches, `rsqrt`, `atan2`, the prelude's `ae_mod` and `ae_mat3`), struct
literals as aggregates. Around them:

- **Conventions are Vulkan's.** A stored depth is clip z as it is, the
  screen's y runs down (`screen_y_sign` is -1), and each vertex shader
  negates its position's y as it returns it, an exact step, so a Metal
  renderer draws with the Vulkan renderer's matrices and viewports and the
  frame comes out the same way up. `[[position]]` in a pixel shader is the
  pixel's centre from the top left, as `gl_FragCoord` is on Vulkan.
- **Nothing is global.** Each block is a struct handed to the entry in a
  buffer, each texture with a sampler beside it, each storage buffer a
  pointer. The entry's first lines name each capture as a reference into
  its block (`constant Eye& eye = ae_set1.eye;`), so the body reads them by
  their GLSL names where it uses them, as the GLSL does (the load order
  MoltenVK's fast math rounds by). A helper reading in place is handed what
  it reads by name, after its own parameters, and so is each helper calling
  it; a helper whose own parameter or local would hide such a name is
  refused, in MSL only.
- **std140 by hand.** MSL's own layout is not std140 (a `float3` takes
  sixteen bytes), so each block struct is written member by member at the
  offsets ae3d.gpu gives it, padded between: a vec3 a `packed_float3`, an
  array of floats, vec2s or vec3s one of `float4`s read through `.x`,
  `.xy`, `.xyz`, an array's element struct of its own with a maker for its
  literals (an aggregate would fill the padding). Each offset and size is a
  `static_assert` in the text.
- **Outputs.** Varyings at `[[user(locnK)]]`, K the location the GLSL gives
  them (an int `[[flat]]` in the pixel shader), attributes at the table's
  `[[attribute(n)]]` (a mat4 four `float4`s), colour outputs four lanes wide
  at `[[color(k)]]` (Metal holds an output to its attachment's channels;
  MoltenVK widens them alike), the depth `[[depth(any)]]`.
- **Bindings**, two rules (written 2026-10-26, when the MSL first drew):
  a pixel shader's resources are numbered as MoltenVK numbers a pipeline
  layout's with its argument buffers off: the blocks and the storage
  buffers `[[buffer(i)]]`, the textures `[[texture(i)]]` and their samplers
  `[[sampler(i)]]`, each kind counted from 0 over the shader's bindings in
  set and binding order. A shader with a block and textures of its own (every
  quoted pass) is `[[buffer(0)]]` and its textures `[[texture(0)]]`, ... in
  capture order, as before. The scene's pixel shader has its draw, camera
  and world blocks (sets 0, 1, 2 at binding 0), its storage buffers and
  textures where `capture_binding` puts them: `lit_quoted` is buffers 0
  (draw), 1 (camera), 2 and 3 (the lamps' storage), 4 (world), and textures
  0 to 9 in binding order (set 0's colour, normal, depth, damage; set 1's
  shadow, lamp shadow, occlusion; set 2's sky light, BRDF, sky irradiance),
  not the order the shader names them in. The count is MoltenVK's where the
  shader names every binding its layouts have, as the scene's do on a device
  with no ray query (a binding the layout has and the shader does not name
  would be a gap to count). A vertex shader's rule is a Metal renderer's to
  choose and untested (below): Vulkan set N's block `[[buffer(N)]]`, the
  storage buffers `[[buffer(8 + k)]]`, textures and samplers in capture
  order, vertex buffers from `[[buffer(16)]]`.

How it is held:

- `generate_shaders --check`: the 41 files are what the trees write.
- `scripts/msl_check.sh`: Metal's compiler, through the device
  (`tools/mslc.m`), with every warning clang has an error but four groups
  (C++98 compatibility, padding, Metal 4's deprecated `vertex`/`fragment`
  keywords, unused parameters). `xcrun metal` needs Xcode's Metal Toolchain
  component, a download, and the script runs it too where it is installed.
- `tests/test_gpu_msl`, no GPU: what each rule writes, the offsets the
  GLSL's block has, and the GLSL and OpenGL's names unchanged by writing MSL.
- Against MoltenVK's own MSL of the same shaders' SPIR-V (its SPIRV-Cross,
  logged with `MVK_CONFIG_DEBUG=1`): every one of the 41 paired, the stage
  interfaces the same (attributes, varying locations, outputs), and 506 of
  ae3d.gpu's offsets asserted on MoltenVK's own block structs compile. That
  is a check of the interfaces and layouts, not of the arithmetic. The
  arithmetic is the next part.

### MSL through MoltenVK (route 1, 2026-10-26)

Nic chose route 1: the Vulkan renderer draws the quoted pixel shaders from
their MSL, and the frames are held to the SPIR-V's. `AE3D_MSL=1` (macOS,
MoltenVK) does it; the default stays SPIR-V.

- **How.** `ae3d.vkmsl` (generated by `generate_shaders`, held by `--check`
  like the rest) carries each fragment shader of `src/ae3d/metal` as the code
  of a shader module: MoltenVK's magic word (`kMVKMagicNumberMSLSourceCode`,
  0x19960412), the text, a NUL, zero padding. `vkpipes.shader` makes the
  module from it for a quoted pixel shader, and `vkdevice.uses_msl` turns
  MoltenVK's argument buffers off (`MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=0`,
  set before the first instance) so its resources are the discrete ones the
  numbering above is. The entry function is renamed `main0` in the module's
  text (the checked-in files keep their own names): that is the name
  MoltenVK finds a direct-MSL module's function by, and the pipeline stage's
  `pName` must be it too (`vkpipes.entry_of`; `main` or the shader's own name
  made the pipeline fail with "function could not be compiled"). The dynamic
  uniform buffer needs nothing: with argument buffers off MoltenVK applies the
  dynamic offset when it binds the buffer.
- **Pixel shaders only.** MoltenVK 1.4.2 refuses a pipeline whose vertex
  module is MSL: "Failed to get vertex outputs: SPIRV file too small". It
  reads the vertex stage's outputs from its SPIR-V to number the fragment
  stage's inputs, for a pipeline of any fragment shader. Its header says
  direct MSL is not officially supported, and for the vertex stage it does
  not work. So the 27 pixel-shader modules a scene run makes are MSL
  (`vkpipes.msl_made`), and the vertex shaders (lit, the sea's, the crowd's,
  the full-screen vertex shader) stay SPIR-V; their MSL is compile-checked
  and its structs and offsets paired with MoltenVK's, as before, and
  evaluated on the CPU, and nothing more until a Metal renderer or route 2
  draws it.
- **Numerics.** MoltenVK compiles a SPIR-V shader with Metal's fast math
  (`MathMode Fast`, fast math functions) and a direct-MSL module safe
  (`MathMode Safe`, precise functions); its log says so
  (`MVK_CONFIG_DEBUG=1 MVK_CONFIG_LOG_LEVEL=4`). Against the default SPIR-V
  the MSL's 1x parity frames differ in 26 of 56 (most by a step in one to
  thirty channels of 147,456), and the two screen-space ones, SSAO and SSR,
  in 769 and 1,001 channels, worst 11 and 13 steps: the rounding of the
  maths in a hash-sampled loop, not a different shader. `#pragma METAL fp
  math_mode(fast)` brings most frames to a channel or two but not those two
  (Metal's fast math functions are a compiler option, and asking for them in
  the source did nothing), so the comparison is made at one mode: the SPIR-V
  side with `MVK_CONFIG_FAST_MATH_ENABLED=0` too (and the MSL run's SPIR-V
  vertex shaders alike). There the arithmetic is the same: **the MSL's frames
  are the SPIR-V's byte for byte.** At 1x, 54 of 56 parity frames; the two
  that differ are the clouds of #793, whose own runs differ by up to 2,649
  channels on Vulkan and by some on OpenGL, which this does not touch. At 4x,
  47 of 56, the clouds again, and seven frames that share the scene's sphere
  at one channel by one step (`lit_quoted`'s MSL against its SPIR-V: the last
  bit of one pixel). No tolerance is needed but #793's, which
  `frames_against` already has, and one channel by one step in those seven
  (the same pixel, 77,80, of the spheres: `lit_quoted`'s last bit).
- **What holds it.** `frames_against.sh` takes `AE3D_HERE_ENV` and
  `AE3D_THERE_ENV` (variables for this tree's draws and the ref's) and
  `AE3D_WITHIN`, `AE3D_OVER` (a tolerance for every frame but the clouds and
  the city), so `AE3D_WITHIN=1 AE3D_OVER=2 AE3D_HERE_ENV="AE3D_MSL=1
  MVK_CONFIG_FAST_MATH_ENABLED=0" AE3D_THERE_ENV=MVK_CONFIG_FAST_MATH_ENABLED=0
  ./scripts/frames_against.sh HEAD` draws the parity cases and zombie_city's
  frames both ways: 59 of 59, 47 of the 56 parity frames byte for byte, the
  clouds and the city within their own tolerances, and `fxaa_vk` and six
  more at the one channel.
  `tests/test_vk_msl` (macOS) draws a scene with the SPIR-V and then with the
  MSL in one process, holds the frames equal byte for byte, and counts the
  modules made from MSL (none for the first draw, at least 20 for the
  second, 27 now): a run that quietly fell back to the SPIR-V would draw the
  same frame, so the count is what shows the MSL was used. Negative controls
  (2026-10-26): the switch ignored fails the count; every `max(` of the MSL
  made `min(` fails the frame (5,415 of 24,576 channels, worst 213); the
  scene's resources numbered by the old capture-order rule fails the frame.

**Done, 2026-10-26: route 1, for the pixel shaders** (above). **What is left, for
Nic: the Metal path (#312)**, after the Vulkan performance pass. Three ways,
smallest first (the first is built, less the vertex shaders):

1. **Our MSL through MoltenVK.** MoltenVK takes MSL source in place of
   SPIR-V (`vkCreateShaderModule`, its MSL magic number), so the Vulkan
   renderer could draw the quoted shaders from `src/ae3d/metal` on macOS
   with nothing else changed, and every frame be held to the SPIR-V path's
   on the M6 (frames_against, parity). It needs the MSL's bindings to be
   the ones MoltenVK assigns (its argument buffers, or its discrete indices
   with `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=0`): a binding rule in the
   dialect, not a backend. It tests the arithmetic, which nothing does now.
2. **A Metal harness for the screen passes.** Draw each quoted full-screen
   pass through Metal itself from a small Objective-C tool, its inputs
   fixed, and hold it to MoltenVK's drawing of the same pass, or to the CPU
   evaluator. No renderer; it proves the MSL, not a Metal path.
3. **The Metal backend** behind the `Backend` vtable, as #312 has it: a
   third renderer, its parity test and the editor's viewport on it. #312
   puts it after the Vulkan performance pass, so the structures it shares
   are the settled ones.

The recommendation is 1: the least new code, and the first time the MSL's
arithmetic is held to frames; 3 after #312's groundwork.


### The upscaler's and depth of field's passes (2026-10-27)

Four more quote shaders, one source each for Vulkan's SPIR-V, OpenGL's GLSL
and the MSL (generated, held by `--check` and the device compiler, appended to
the generator's table so no constant moved): `ae3d.shaders.upscale` (`easu`,
`rcas`: #867) and `ae3d.shaders.dof` (`dof_coc`, `dof_gather`: #870). The
composite takes a third texture, `dof`, and a flag, `dof_on`; the textures are
still bound by the order the body first reads them (screen, bloom, dof), and
the block gains an int. Under `AE3D_MSL=1` the four are among the pixel shaders
MoltenVK takes as MSL (vkmsl), held to the SPIR-V's frames by the same recipe
as above (one math mode on both sides); their vertex shader is the full-screen
one, SPIR-V as before.

What the shaders needed of `ae3d.shaderlib`/`ae3d.gpu`, none of it new:
`texel_fetch` for an exact read (the upscaler's taps, the depth's four texels:
no sampler's filter, so Vulkan's nearest and OpenGL's agree), `texture_size`,
`float_of` for the gather's loop, and `screen_y_sign()` to turn the gather's
spiral the same way in the picture on both renderers (OpenGL's rows run up,
Vulkan's down: unturned, the two disagreed in 4% of a frame wherever the blur
was wide). A struct local to a helper (`EdgeAxis`) is returned by value, as
`HazePoint` is.


### The environment map's capture (2026-10-27)

One more quote shader, `ae3d.shaders.envmap.env_capture` (#869): each texel of
the sky's 256-texel octahedral capture reads a user's equirectangular map in the
texel's direction (the same texel-to-direction rule as the sky's capture, the
painted sky's longitude and latitude, repeat in longitude, latitude held a half
texel off the poles, a mip level, an intensity and a yaw (radians, Nic 875-6:
subtracted from the azimuth before the longitude is formed, so 0 is the same
arithmetic as before) as captures). One source for
SPIR-V, OpenGL's GLSL and the MSL (generated, held by `--check` and the device
compiler, appended to the generator's table so no constant moved). It replaces
`sky_capture` in the capture's place and nothing after it, so the irradiance
and prefilter passes, the table and every reader of them are unchanged; under
`AE3D_MSL=1` it is among the pixel shaders MoltenVK takes as MSL. The map's
texture is RGBA16F with a mip chain made by blits (Vulkan) or `glGenerateMipmap`
(OpenGL).

### The world text's pair (2026-10-28)

One more quote pair, `ae3d.shaders.lettering` (`world_text_vertex`,
`world_text`: #871), SPIR-V, GLSL and MSL from the one source (generated and
held by `--check` and the device compiler like the rest; the pixel shader is
among the MSL ones MoltenVK takes under `AE3D_MSL=1`). The module is lettering,
not worldtext: `ae3d.worldtext` is the engine's, and two modules of one last
name in a program confuse a quote's helpers.

The shapes it is made of, none of them new to `ae3d.gpu`:

- the vertex shader reads the mesh vertex's attributes by the table's names
  (`position`, `uv`, `normal`, `occlusion`) and an instance's matrix
  (`instance_model`), so the pair is a mesh pair (`vkquote.mesh_pair_new`) on
  Vulkan with no new vertex input, and a vertex array in a mesh's layout on
  OpenGL. A glyph's layout pixel is in the position, its atlas place in the
  uv, its colour in the normal's three floats and its alpha in the baked
  occlusion's; the run is the draw's one instance: its right and up axes with
  the scale in them (a billboard's the camera's, chosen by the renderer from
  the view matrix, so the shader has no branch for the kind of run), its
  point, and in the first column's w whether it is drawn over everything. One
  vertex buffer and one instance buffer a frame slot, one `vkCmdDraw` a run
  (the run's number is the draw's `firstInstance`), one set of values for the
  frame (the pair's two captures are the matrices, from the scene block, and
  the jitter). OpenGL sets each run's four matrix columns as the generic
  attribute (`glVertexAttrib4f`) before its draw.
- "Over everything" is the depth test every draw makes, passed: `depth_clip`
  of a hundredth of a percent, times w, as the clip z, so Vulkan's 0..1 and
  OpenGL's -1..1 are each right (the OpenGL GLSL is `(0.0001 * 2.0 - 1.0)`),
  and the pipeline is one pipeline.
- The glyph's coverage is the atlas's distance against 0.5 with the pixel's
  width from `dFdx` and `dFdy` of the distance itself; a pixel with no coverage
  is `discard()`ed, so the scene's second attachment keeps the motion vector
  of what is behind it.
- The HUD's atlas on Vulkan is one byte a texel; the world text reads it as the
  device texture `vktexture.texture_create_rgba` makes of it (the distance in
  red, one level), made again when the HUD's font changes. A texture of its own
  rather than the overlay's: the overlay's is uploaded inside the overlay's
  hook, after the scene pass the text is drawn in, and a view's frame (a
  different format) must not remake the overlay's pass.

It draws in `renderer_render`, after the transparent surfaces and before the
frame ends, so a view's frame draws it with the view's camera and the post
chain (the temporal pass, the upscaler, depth of field, the bloom, the
composite) sees it as part of the scene's light. It writes no depth, so depth
of field blurs it by what is under it; the pick pass runs before it, so it is
not picked.
