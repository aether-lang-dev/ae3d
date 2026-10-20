### The figure's reflection is judged by its own part, not the road's

- **`tools/critique_scene.ae`: what lies under the figure's feet is held
  to what the reflection adds there over the road's own reflection of the
  same cells with the figure gone**, not to the whole of it. zombie_street
  (critique, vulkan) read 0.22 under the feet against 0.20 since the scene
  was lit as light (#655, #656, bc42f4a9; bisected over the first-parent
  history: f2969f17 0.07, 6fa827bc 0.20, main 0.22). Measured at
  320x180 on the M6, the same rows and columns with the figure's models
  hidden: the road's own reflection there went from 0.02 to 0.15, and the
  figure's part from 0.05 to 0.08. The report says both. A reflection four
  times as strong (strength 6) read 0.59 whole and 0.09 the figure's.
