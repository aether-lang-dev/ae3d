# glTF fixtures

## Morph targets (#910)

Three of Khronos' glTF sample models, committed as test fixtures only (`tests/test_morph.ae`, `benchmarks/bench_morph.ae`), each under the licence its `metadata.json` in [glTF-Sample-Assets](https://github.com/KhronosGroup/glTF-Sample-Assets) gives, and a file written by hand for this repository. The `.glb` files are the samples' `glTF-Binary/` files, unchanged.

| file | what it is | licence and attribution | sha256 |
|---|---|---|---|
| `AnimatedMorphCube.glb` | A cube with two morph targets (POSITION, NORMAL and TANGENT offsets) and a LINEAR weights animation of 127 keys. | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/), Microsoft, 2017. `Models/AnimatedMorphCube` | `214ee56160a50dbf22543a1d66dbf860986e87f0efac3d89feac1359d0e6aeab` |
| `MorphPrimitivesTest.glb` | One mesh of two primitives sharing one target's weight. | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): "Morph-Primitives Test" by ft-lab, 2018. `Models/MorphPrimitivesTest` (the plain file, not its Draco-compressed one) | `2a5ed6470aca41edc813ef5b7eecf2af53264d8e0ab9e6f32156d54245ca18cf` |
| `MorphStressTest.glb` | Eight morph targets a primitive, named (`extras.targetNames`), with weights animations. | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): "Morph Stress Test" by Ed Mackey, © 2021 Analytical Graphics, Inc. `Models/MorphStressTest` | `005f1d9dd938c553a506d6bf3d21830fc3f2ec3a199d9332e9a625baf7342bef` |
| `morph_sparse.gltf` | A quad with two sparse POSITION targets -- one with no buffer view (zeros, two vertices substituted), one substituted over its view -- named `lift` and `bulge`, default weights 0.5 and 0.25, and a CUBICSPLINE weights animation. Its buffer is a base64 `data:` URI. | Written for ae3d's tests; the repository's licence. | |

No face with blend shapes is committed: none of these is a face, and a CC0 face with an ARKit-like set of shapes (#910's face set) is still to be found. The repository ships importers, not character assets (#342); a face would come in under the same test-only exception as `../people/`.

The other files here (`Fox.glb`, `arm.*`, `embedded.glb`, `humanoid.glb`, `ik_man.glb`, `sparse_*.gltf`) predate this README.
