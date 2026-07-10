# Model3D tests

`PBRViewer.ts` is the interactive glTF/PBR viewer. `P0Regression.ts` is the deterministic regression and lifecycle runner used by the 3D production-readiness roadmap.

## Interactive viewer

```sh
./Test/Model3D/run-pbr-viewer.zsh
```

## Automated P0 regression

Start the current engine once, then run the regression:

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
