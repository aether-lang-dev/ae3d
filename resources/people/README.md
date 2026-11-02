# People: textured CC0 figures for the showcase and the README

Six of Quaternius's modular people, so the engine's pictures and its animation showcase show people rather than the test mannequins. They ship with the repo by the owner's decision of 2026-11-02 (#902). The rule from #342, that the repo ships importers and not game assets, still holds for everything else. The mannequins in `tests/fixtures/people` remain the figures the tests are held to.

All six are by Quaternius and are dedicated to the public domain under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/): the [Ultimate Modular Men](https://quaternius.com/packs/ultimatemodularcharacters.html) and [Ultimate Modular Women](https://quaternius.com/packs/ultimatemodularwomen.html) packs. The files are the single-character glTF exports of those packs published at https://github.com/trebeljahr/quaternius-showcase (`public/glb/modular_men/` and `public/glb/modular_women/`), which records both packs as CC0-1.0 in its `LICENSES.md`. They are unchanged here; only their names are.

| file | from | sha256 |
|---|---|---|
| `man_casual.glb` | `modular_men/Casual.glb` | `dc2d86e50075e372df870bb60cee46c56033cc2ecb28722523caab93ab1d0111` |
| `man_suit.glb` | `modular_men/Suit.glb` | `a9896c1468fadbd24a89a2f86eecd8d47ae5ec6b3ef267b2194dc3b8bb9fb3d0` |
| `man_worker.glb` | `modular_men/Worker.glb` | `1c07d49d6ef060fb3d69897d91334093d389f0e729a874d7647fdb6b59f92127` |
| `woman_casual.glb` | `modular_women/Casual.glb` | `522cd442880c6769bdf079f1a2161a1aaffe78b32f1de64fb990644b2e327fea` |
| `woman_formal.glb` | `modular_women/Formal.glb` | `f1b635c27f9fc2b200eb188ba18c625e7d9b0e19d46e8e4d1695e6100fa3735d` |
| `woman_worker.glb` | `modular_women/Worker.glb` | `00bd8f9da25b9196f61d2f4d9f21972f98632665926ed4da2652c0c020fd0bc6` |

## What the pipeline makes of them

- **They carry no clips.** Their gaits come from the mannequins' authored clips and from 100STYLE's captures, retargeted onto them (`ae3d.retarget`), as any figure's do.
- **Their skeletons use Quaternius's modular naming:** `Hips`, `Abdomen`, `Torso`, `Chest`, `UpperArm.L`, `UpperLeg.L` and so on, with fingers. `ae3d.pose` maps it as `SCHEME_QUATERNIUS`. The women's hands number their fingers from 1 and map whole; the men's number from 2 and map in part.
- **They have no toe joints.** Each foot's heel, pad and toe are measured from the flesh the foot carries, at about 24 to 26 cm heel to toe (`ikrig`'s `flesh_feet`).
- **Each is made in parts, with a skin a part** (four skins over the same 51 or 49 joints). The rig keeps every skin (`pose.add_skin`), so a foot's flesh is found in whichever skin carries it.
