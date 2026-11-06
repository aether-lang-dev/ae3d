### The draw count is the scene's draws, the same on both renderers (#882)

- One rule, applied everywhere: a full-screen pass of the frame's own is not a draw of the scene's, so neither
  renderer counts it. On Vulkan a quoted pass (`vkframe.draw_quoted_with`) no longer counts, so the depth's resolve
  and the occlusion's pass, drawn inside the scene before the count is read, are gone from it; the
  `counted = g_draw_calls ... g_draw_calls = counted` guards round the sky's capture, the bloom, depth of field and
  the screen passes are gone with it (dead for the post chain, which runs after the count is read, and redundant
  now for the rest). On OpenGL the reflections' pass, the temporal pass and the HUD overlay no longer count.
- Until now each renderer counted some screen passes the other did not, so their counts disagreed by whichever
  passes were on: in `test_backend_parity`'s scene, 7 draws with nothing on became OpenGL 7 / Vulkan 9 with the
  occlusion, 8 / 8 with the temporal pass, 8 / 8 with the reflections, 7 / 8 with depth of field, 9 / 9 with all
  four. zombie_street's 88 on both was two different 88s (OpenGL's reflections, Vulkan's resolve).
- `docs/rendering.md`, "What a frame's draw count is": what is counted and what is not.
- Tests: `test_backend_parity` holds the count with the occlusion, the temporal pass, the reflections and depth of
  field each on and all on to the count with none (7), on both renderers, and the renderers to each other. On the old
  renderers 5 of its checks fail (the counts above).
- Budgets re-recorded for the draw count alone (on the M6, 320x180, as `ci_scenes` runs them; triangles, binds and
  times unchanged): zombie_street 88 -> 87 on OpenGL and on Vulkan, zombie_city's shadow-map budgets (near band 12 m
  and 28 m) 696 -> 694 (the resolve and the occlusion's pass). The RTX 4070 Ti's ray-traced budgets
  (`zombie_city*.vulkan.budget.json`, 285) were recorded on that card and are not re-recorded here: no device here
  traces rays. They will read one fewer (the resolve) or two (with the occlusion's pass, if the rays' occlusion is
  off), to be recorded again there with `ae3d_bench --record`.
