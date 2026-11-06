# Community project compatibility

## Heart Bridge / 心-桥 on Godot 4.7.2

Source: <https://gitcode.com/kayingbei/heartbridge>, revision
`84e61436c78e81c11fcb9342ec427a9bc7886eae`. The author's repository and game
content remain unchanged. `heartbridge-4.7.patch` is a project-side adaptation
of its bundled Dialogic version, not a change to Dora or Godot.

Apply in a checkout of that revision:

```sh
git apply --check /absolute/path/to/heartbridge-4.7.patch
git apply /absolute/path/to/heartbridge-4.7.patch
```

The patch fixes missing fallback returns in property hooks, incorrect editor
bottom-panel removal, and temporary subsystem Node allocations made only for
type inference. Typed getter aliases preserve completion without allocation;
the corresponding generator is patched too.

Import with the official Godot 4.7.2 editor before loading the source directory
with GodotPlayer. A fresh custom-font import can initially report missing
generated font data: complete the import and check the next editor start. Do
not treat persistent parse/import errors as success. The adapter does not
silence editor warnings: two ObjectDB instances are still reported on the
headless editor's exit, while the tested Dora runtime exits without warnings.

Local macOS Metal acceptance (2026-11-06): Heart Bridge → Guardian of the Bridge
→ Heart Bridge, one LibGodot and three fresh SceneTrees, 4/3/2 buffers, 12
captures. Producer frames 2509/491/484; unload objects/resources/nodes
241/1/0 → 240/1/0 → 241/1/0. No GPU errors, outstanding reads, blits or audio
underruns. A separate authored `res://Room/start_game.tscn` gameplay smoke
passes another 493 frames / four captures with mouse input and valid PCM.
This is not full-game completion or a claim about other platforms.

The generic runner `../run_community_project_switch.py` consumes JSON with
`host` (a production `project.py run --no-run` staging directory), `runtime`,
fresh `output`, and sequential `items`. Items supply prepared project `path`,
`name`, `width`, `height`, `buffers`, optional `scene`, optional four
`captureTimes`, and optional `minColors` (at least 16, for a verified monochrome menu), and `events` containing `time` / `pressed` plus `key` or `x/y`.
It records images, native instance/tree identity, frames, cleanup, GPU and audio
evidence and fails on script/runtime errors, leaks and dirty unloads.

Detailed local evidence: Dora-SSR `build/godot-4.7-community/REPORT.md`.
Original failures and official 4.7.2 controls remain recorded in that report.

## Bridge of Memories / 渡忆之桥

Source: <https://gitcode.com/kayingbei/bridge_of_memories>, revision
`71e5f70080a295bff7ce35b4241e3127ddabb526`. Apply
`bridge-of-memories-4.7.patch` in a matching checkout (`git apply --check`
before applying). The patch removes the unused global `class_name Hurtbox`
from the inline Area2D script in `scenes/player.tscn`; global class registration
is not valid in an inline script. The game's player already types the node as
Area2D and does not reference that global name. The original checkout remains
unchanged; the adapted copy passes gameplay entry, input and unload on macOS
Metal with Godot 4.7.2.

## JumpBox / 跳跃的箱子

Source: <https://gitcode.com/kayingbei/jump-box>. No project patch is applied.
Dora's shared project unload now records pre-project Node identities, deletes
only newly created detached roots after the SceneTree is destroyed, and protects
pre-existing Nodes and any ancestors containing them. Deletion uses revalidated
ObjectIDs outside ObjectDB's scan lock, with a bounded drain; canceled deletion
and ambiguous ownership remain visible as residuals. This does not force-delete
arbitrary Objects, RefCounted cycles, native extensions or external side effects.

On macOS Metal, unmodified JumpBox → adapted Bridge → JumpBox → Bridge →
JumpBox passes 20 captures with 2/3/4 buffers and no script errors, GPU errors,
pending reads, blits, audio underruns or exit leaks. Each JumpBox unload frees
four detached roots (12 nodes); every unload ends with zero Nodes and one
cached resource. Warm JumpBox object counts are 254/254; Bridge counts are
250/250. JumpBox emits silence in this tested segment; Bridge emits valid PCM.
Other platforms' shared code received targeted compilation, not new dynamic
acceptance. Detailed evidence: Dora-SSR `build/godot-project-orphan-cleanup/`.

