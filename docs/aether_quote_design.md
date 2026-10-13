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

This is the body of `src/ae3d/vkspirv/glsl/fxaa_vk.frag`, which today is GLSL
text. The uniform block, the sampler and the `in`/`out` declarations
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
5. **MSL**, then a SPIR-V writer of our own (after reading Chris's
   `spirv.inc` for ideas, then writing ours from the SPIR-V spec), with
   glslang and `spirv-val` kept in CI as the checkers.
6. **Vertex shaders.** ChrysaLisp's split is worth taking as an idea: a
   vertex shader's inputs and outputs are declared, and one vertex shader
   serves any pixel shader whose inputs it provides. For us the vertex
   quote's return type is a struct of varyings, built with a struct literal
   (`MAKE`, which is why v1 has one), and the pixel quote takes it as its
   parameter.

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
