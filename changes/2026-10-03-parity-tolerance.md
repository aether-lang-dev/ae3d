### Renderer parity held to 1 on a GPU (#503)

- `tools/scene_parity` holds each region to 1.0 of 255 on a GPU and to 2.0
  on a software rasteriser (llvmpipe, lavapipe, SwiftShader), named by the
  devices the two scenes report. Every region was held to 2.
- Over three gates the worst region mean on an RTX 4070 Ti is 0.4 (sky 0.3,
  facades 0.4, road 0.3, figures 0.3, the rest 0.4). The residuals #503 was
  filed for are under the noise: the wet road's streak in street_drive's
  60 by 60 pixels around cell (18, 11) is 0.38 apart, read pixel by pixel
  with the reflections off (4.7 when filed), and zombie_city view 3 is 0.4.
- Tried and not merged: one mip chain built on the CPU and uploaded to both
  renderers. The same box came to 0.33, against 0.38, for a chain built on
  the CPU at every texture load.
