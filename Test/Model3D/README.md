# Model3D tests

`PBRViewer.ts` is the interactive glTF/PBR viewer. `P0Regression.ts` is the deterministic regression and lifecycle runner used by the 3D production-readiness roadmap.

## Interactive viewer

```sh
./Test/Model3D/run-pbr-viewer.zsh
```

## Automated P0 regression

Before any runner starts the engine with `dora cli doctor --fix`, close every Dora Web IDE tab. The runners close matching tabs in Chrome, Edge, and Safari before killing the old Dora process. Automation using the Codex in-app browser must close its Dora Web IDE tabs separately before invoking a runner, because those tabs are not controlled by AppleScript.

Then run the regression:

```sh
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
	-u ALL_PROXY -u all_proxy -u NO_PROXY -u no_proxy \
	zsh -ic 'dora cli doctor --fix'
./Test/Model3D/run-p0-regression.zsh
```

The runner compiles the TypeScript source, stages it under `/tmp/dora-3d-test`, and runs it with `dora cli run -p /tmp/dora-3d-test`. It produces:

- seven TGA and PNG screenshots under `/tmp/dora-3d-p0`;
- per-case frame statistics in `/tmp/dora-3d-p0/result.txt`;
- RSS samples and a summary under `/tmp/dora-3d-p0`, including a separately marked 300-switch interval;
- a 300-switch lifecycle result and post-`Cache.removeUnused()` registry counts;
- RMSE comparison against `Baselines/metal` with a normalized threshold of `0.05`.

To replace the Metal reference images after an intentional visual change:

```sh
./Test/Model3D/run-p0-regression.zsh --update-baseline
```

Reference images for another rendering backend must be generated and reviewed on a platform actually running that backend. Do not copy the Metal images into another backend directory.

```sh
DORA_3D_BACKEND=vulkan ./Test/Model3D/run-p0-regression.zsh --update-baseline
DORA_3D_BACKEND=vulkan ./Test/Model3D/run-p0-regression.zsh
```

## Animation scale profile

Before running a local profile, close existing Dora Web IDE browser tabs. The runner restarts the native engine, compiles the TypeScript source, and samples `1`, `10`, `25`, and `50` concurrently playing Fox instances:

```sh
./Test/Model3D/run-animation-scale-profile.zsh
```

Results are written to `/tmp/dora-3d-animation-profile/result.txt`. The output includes frame, collect, sort, and submit P50/P95 values and verifies that every phase releases all model instances.

## Directional shadow

`DirectionalShadow3D.ts` compares the same scene before and after enabling `DirectionalLight3D.castShadow`. It includes a static Duck, an animated skinned Fox, and a deterministic glTF ground receiver:

```sh
./Test/Model3D/run-directional-shadow.zsh
```

The runner writes disabled/enabled screenshots and `SHADOW_SUMMARY` to `/tmp/dora-3d-shadow`.

## Character controller

`CharacterController3D.ts` verifies the JOLT-C virtual capsule controller by falling onto a static floor, walking, jumping, landing again, and checking the foot-position convention:

```sh
./Test/Model3D/run-character-controller.zsh
```

The runner writes `CHARACTER3D_SUMMARY` and a reviewed steady-state screenshot to `/tmp/dora-3d-character`.

## Compound collision shape

`CompoundShape3D.ts` builds an offset box-and-sphere collision shape, freezes it, creates one dynamic body for two visible ducks, and verifies both convex parts through raycasts after landing:

```sh
./Test/Model3D/run-compound-shape.zsh
```

The runner writes `COMPOUND3D_SUMMARY` and a reviewed screenshot to `/tmp/dora-3d-compound`.

## Mesh collider

`MeshCollider3D.ts` loads and cooks a glTF triangle mesh through Dora Content asynchronously, verifies cache reuse, creates a static mesh body, and confirms it through a raycast:

```sh
./Test/Model3D/run-mesh-collider.zsh
```

The runner writes `MESH_COLLIDER3D_SUMMARY` and a reviewed screenshot to `/tmp/dora-3d-mesh-collider`.

## Constraints

`Constraint3D.ts` runs fixed, distance, and limited hinge constraints together. It verifies the constrained degrees of freedom, endpoint references, and the empty-wrapper state after explicit destruction:

```sh
./Test/Model3D/run-constraint-3d.zsh
```

The runner writes `CONSTRAINT3D_SUMMARY` and a reviewed screenshot to `/tmp/dora-3d-constraint`.

`ConstraintPlayground3D.ts` is the interactive companion demo. It switches between fixed, distance, and limited hinge constraints, supports direct duck dragging, configurable impulses and limits, AABB visualization, and live break/rebuild operations:

```sh
./Test/Model3D/run-constraint-playground.zsh
```

## JOLT feature labs

The interactive labs complement the deterministic regression cases and expose the full current JOLT feature surface:

| Lab | Covered features |
| --- | --- |
| `JoltDynamicsLab3D.ts` | Box/sphere/capsule, static/kinematic/dynamic bodies, gravity, force, impulse, linear/angular velocity, direct dragging, contacts, sensors, layer masks, raycast and sphere overlap |
| `JoltShapeLab3D.ts` | Reusable primitive shapes, immutable compound builder, shared compound bodies, async glTF mesh cooking through Content, cache reuse, static/kinematic mesh and dynamic concave rejection |
| `JoltLifecycleLab3D.ts` | Body-triggered constraint cleanup, world-triggered body/constraint/character cleanup, wrapper empty-state checks and incremental 100/1000-cycle stress |
| `CharacterController3D.ts` | CharacterVirtual movement, grounding, slope/step settings, jumping and foot-position synchronization |
| `ConstraintPlayground3D.ts` | Fixed/distance/hinge constraints, limits, direct interaction, impulses and break/rebuild |

```sh
./Test/Model3D/run-jolt-dynamics-lab.zsh
./Test/Model3D/run-jolt-shape-lab.zsh
./Test/Model3D/run-jolt-lifecycle-lab.zsh
./Test/Model3D/run-character-controller.zsh
./Test/Model3D/run-constraint-playground.zsh
```

All four physics labs expose a `Physics Debug` toggle. It draws actual Jolt collider world bounds: green for static bodies, yellow for kinematic bodies, cyan for dynamic bodies, and magenta for sensors. This is separate from `View3D.showAABB`, which only visualizes render bounds.
