# sageattention recipe

| Field | Value |
|-------|-------|
| app | sageattention |
| upstream | https://github.com/thu-ml/SageAttention.git |
| mode | pinned |
| pin | 7688d781fa6022649daacf6b9c4ad267c83df6b4 |
| pin-reason | the wheel must match the consumer comfy environment exactly; the build refuses toolkit/torch combinations the 3090 build must tolerate, so the NVCC version checks are patched out |
| output | `src/sageattention/dist/*.whl` (stays in tree; no copy step) |

## Env

| Component | Version |
|-----------|---------|
| python | 3.12.12 (build venv) |
| torch | 2.12.1+cu130 (CUDA 13.0 runtime) |
| CUDA toolkit (nvcc) | 13.3 |
| host compiler | gcc-15 via `CC`/`CXX` exports (system gcc 16.2.1 is too strict for torch 2.12.1 headers: `-Wtemplate-body` errors; torch derives the nvcc `-ccbin` from `CXX`) |
| GPUs | 2x NVIDIA RTX 3090 (sm_86) |

## Build

1. Source checkout: `src/sageattention` (submodule, `update = none`, `shallow = true`)
2. Build venv: `src/.venv/` (git-ignored); build.sh seeds it by moving the venv named in `SAGEATTENTION_SEED_VENV` with path rewrite when that variable is set, else creates a fresh venv and installs the declared torch
3. Run `./build.sh`: applies `patches/0001` to `src/sageattention`, `patches/0002` to the venv's torch `cpp_extension.py` (both idempotent), sets `EXT_PARALLEL`, `NVCC_APPEND_FLAGS`, and `MAX_JOBS` with a 1-GPU baseline (4x, 4x, and 8x per GPU); GPU detection scales the values up when more cards are present (2 cards give 8/8/16), then `setup.py bdist_wheel`
4. The wheel lands in `src/sageattention/dist/`; the consumer installs it (`pip install --force-reinstall`)

## Patches

- `0001-setup-py-disable-nvcc-cuda-checks.patch`: comments the NVCC CUDA version validation block in `setup.py`
- `0002-torch-cpp_extension-allow-cuda-major-mismatch.patch`: comments the CUDA major version mismatch raise in torch `utils/cpp_extension.py` (outside the source repo; applies to the build venv)

## Known issues

- nvcc 13.3 (CUDA 13.3, `/opt/cuda`) cannot parse torch 2.12.1 headers: its EDG front-end rejects `ATen/core/List_inl.h:202` with a `-Wtemplate-body` error that real gcc does not produce (g++-15 and g++-16 accept the same file standalone; verified). `-fpermissive` only downgrades it to an instantiation-time error; `-Wno-template-body` is rejected by nvcc; the emulated `--gnu_version` follows nvcc's own detection and is not affected by `-ccbin` or PATH shims. Consequence: this pin cannot be rebuilt against torch 2.12.1 until nvcc ships a fixed EDG, an older CUDA toolkit is used, or the pin moves to a SageAttention commit supporting CUDA 13. The February-built wheel (`sageattention 2.1.1`, installed in the seed venv) imports cleanly against torch 2.12.1, so the consumer keeps working.
