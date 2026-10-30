# PIZ fixtures

OpenEXR PIZ files for `tests/test_envimage.ae`, and what they are held to.

## `piz_*.exr`

Written by the official OpenEXR library (3.5.2, BSD-3-Clause) through `tools/exr_reference/exrref.cpp`, for
example `exrref write piz_rgb_half_grad.exr 37 45 piz RGBh grad` (channels and pattern are in the table below;
the patterns are in the tool, with a fixed random seed, so a rebuild writes the same files).
The test compares what `ae3d.openexr` decodes with the library's own decode of the same file (`exrref dump`, the
two hashes in the test source), bit for bit. The tool is a development aid: nothing of OpenEXR is linked into
ae3d or built by `ci.sh`.

| file | size | channels | pattern | covers |
|---|---|---|---|---|
| piz_rgb_half_grad | 37x45 | RGB half | smooth HDR gradient | a width and height that are nothing convenient; blocks of 32 and 13 lines |
| piz_rgba_half_grad | 100x70 | RGBA half | gradient | alpha kept; three blocks |
| piz_rgb_float_hgrad | 53x33 | RGB float | gradient rounded to half precision | FLOAT as two 16-bit planes (a float gradient at full precision does not compress, the library stores it raw) |
| piz_rgba_float_hgrad | 90x48 | RGBA float | the same | |
| piz_rgb_half_bitramp | 600x64 | RGB half | R counts up through the half bit patterns | over 16384 different values in a block: the 16-bit wavelet (the 14-bit form is used below that), and long Huffman codes |
| piz_rgba_float_bitramp | 600x64 | RGBA float | R counts up through the float bit patterns | the 16-bit wavelet on FLOAT |
| piz_rgb_half_lowrange | 91x65 | RGB half | 9 distinct values | the 14-bit wavelet, a tiny bitmap |
| piz_rgba_half_sparse | 200x40 | RGBA half | mostly zero | run codes of zeros |
| piz_rgb_half_ramp | 64x40 | RGB half | x, y, x + y | runs of a nonzero difference (the Huffman run code repeating a nonzero word) |
| piz_one_line, piz_one_line_float | 1000x1, 600x1 | RGB half, RGBA float | ramps | a single scanline |
| piz_one_column | 1x800 | RGB half | ramp | a width of 1 (no horizontal wavelet), 25 blocks |
| piz_narrow | 4x600 | RGBA half | one colour | a width of 4, 19 blocks |
| piz_flat, piz_flat_float | 30x20, 31x33 | RGB half, RGBA float | one colour | the smallest Huffman tables |
| piz_black | 30x20 | RGB half | all zero | only the value 0 (no bitmap at all) |
| piz_h32, piz_h33, piz_h64 | 40x32, 200x33, 40x64 | RGBA half | gradient | a height exactly 32, one over (a one-line last block), exactly 64 |
| piz_grey_half, piz_grey_float | 100x38, 200x40 | Y | gradient | a lone luminance channel |
| piz_window | 100x36 | RGBA half | gradient | a data window from (-3, 5) |
| piz_wide | 1000x3 | RGB half | gradient | a short block, a wide line |
| piz_stored_raw | 64x64 | RGB half | random bit patterns | blocks the library stored uncompressed, as PIZ does when it gains nothing (noise, tiny pictures) |
| piz_fuzz_half | 23x35 | RGB half | gradient | small, for the cut-at-every-length and damaged-at-every-byte loops |

A block the library did not gain on is stored as it is, so a small or noisy picture exercises the PIZ path only
in the blocks that did gain: `tools/exr_reference/blocks.py` says, per block of a file, `raw` or how many different
16-bit values it holds (16384 or more is the 16-bit wavelet).

## `polyhaven/`

Two real assets, the 1k OpenEXR files of Poly Haven HDRIs, both PIZ-compressed FLOAT RGB, 1024 x 512, unchanged
from the download:

- `abandoned_tank_farm_05_1k.exr`, https://dl.polyhaven.org/file/ph-assets/HDRIs/exr/1k/abandoned_tank_farm_05_1k.exr
  (asset page https://polyhaven.com/a/abandoned_tank_farm_05), 1,256,573 bytes
- `aerodynamics_workshop_1k.exr`, https://dl.polyhaven.org/file/ph-assets/HDRIs/exr/1k/aerodynamics_workshop_1k.exr
  (asset page https://polyhaven.com/a/aerodynamics_workshop), 1,395,541 bytes

Licence: CC0 1.0 Universal (public domain dedication), per https://polyhaven.com/license. Downloaded 2026-10-28.
