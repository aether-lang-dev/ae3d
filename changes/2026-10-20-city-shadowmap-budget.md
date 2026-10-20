### zombie_city at 20,000 has a budget where the shadow map stands

- **A device without ray query is held to a budget of its own**
  (`resources/zombie_city*.vulkan.shadowmap.budget.json`, recorded on an
  Apple M6; `tools/ae3d_bench --shadow-map-baseline` takes it when
  `frame.stats` says the frame's shadows were not traced, its new
  `render.ray_shadows`). The recorded budgets are the RTX 4070 Ti's, where
  the city is shadowed by ray; without ray query the shadow map draws every
  cascade's and lamp face's casters: on the M6 410 of the frame's 701 draws
  were in the shadow pass (counted at each draw site in vkframe), the other
  291 against the 4070 Ti's 285, and six shadow pipelines more (11 against
  5). Both near bands failed `./ci.sh` on the M6 at every commit since the
  budget was recorded (e69f3a56 read 696 draws there too). Run to run on the
  M6 the counts are the same and the passes within 0.05 ms.
