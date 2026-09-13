# SageAttention wheel builder for NVIDIA RTX 30-series

> **Main repository**: https://gitlab.com/lyoneel/sageattention-nvidia-rtx-30xx-series-gpus.
> If you are reading this on any other host, it is a mirror. Please
> open issues and merge requests on GitLab.

Build the SageAttention extension wheel from source on a machine with
NVIDIA RTX 30-series GPUs. The wheel accelerates attention inference
(INT8 quantized kernels) for transformer and diffusion models.

## What this folder does

1. Pins the upstream SageAttention source at a tested commit.
2. Applies a small patch series that removes CUDA version checks.
3. Runs one script that prepares the build environment and produces
   the wheel.

The wheel lands in `src/sageattention/dist/`. Install it with
`pip install --force-reinstall <wheel-file>`.

## GPU compatibility

- Tested on NVIDIA GeForce RTX 3090.
- Should work on all RTX 30-series GPUs (3050 through 3090 Ti):
  they all use compute capability 8.6.
- The build compiles kernels only for the GPU architectures it
  detects on the build machine. A build on a 3090 produces 8.6
  binaries, which run on the whole RTX 30-series line.
- Other GPU generations (RTX 20, 40, 50, A100, H100) are not
  included in this build.

## Requirements

| Component | Version |
|-----------|---------|
| python | 3.12 (build venv) |
| torch | 2.12.1+cu130 (installed into the build venv) |
| CUDA toolkit (nvcc) | 13.3 |
| host compiler | gcc-15 (recommended; the script builds a shim when present) |
| GPU | NVIDIA RTX 30-series |

## Usage

```bash
git clone https://gitlab.com/lyoneel/sageattention-nvidia-rtx-30xx-series-gpus.git
cd sageattention-nvidia-rtx-30xx-series-gpus
./build.sh
```

`build.sh` fetches the pinned source submodule on first run, so no
manual submodule step exists. The source is pinned at the tested
commit `7688d781fa6022649daacf6b9c4ad267c83df6b4`.

Optional: seed the build venv from an existing venv to skip the torch
download.

```bash
SAGEATTENTION_SEED_VENV=/path/to/existing/venv ./build.sh
```

The script is the single entry point. It creates the build venv,
applies the patches in an idempotent way, sets up the compiler
environment, and runs `setup.py bdist_wheel`.

## Parallel build

The script assumes 1 GPU and sets parallel degrees 4, 4, and 8
(`EXT_PARALLEL`, nvcc threads, `MAX_JOBS`). GPU detection scales the
values up when more cards are present: 2 cards give 8, 8, and 16.

## Contents

| Path | Purpose |
|------|---------|
| `recipe.md` | Build contract: pin, environment versions, steps, patch list, known issues |
| `build.sh` | Single rebuild entry point |
| `patches/` | Ordered patch series applied to the upstream source and to torch |
| `src/sageattention` | Submodule: upstream source at the pinned commit |

## Status and known issues

- nvcc 13.3 (CUDA 13.3, `/opt/cuda`) cannot parse torch 2.12.1
  headers. Its EDG front end rejects `ATen/core/List_inl.h:202` with
  a `-Wtemplate-body` error that real gcc does not produce. g++-15
  and g++-16 accept the same file standalone (verified).
  `-fpermissive` only downgrades it to an instantiation-time error.
  `-Wno-template-body` is rejected by nvcc. The emulated
  `--gnu_version` follows nvcc's own detection and is not affected
  by `-ccbin` or PATH shims.
- Consequence: this pin cannot be rebuilt against torch 2.12.1 until
  nvcc ships a fixed EDG, an older CUDA toolkit is used, or the pin
  moves to a SageAttention commit that supports CUDA 13.
- The February-built wheel (`sageattention 2.1.1`) imports cleanly
  against torch 2.12.1, so existing installs keep working.

## Credits

Based on [SageAttention](https://github.com/thu-ml/SageAttention) by
thu-ml. This folder only packages the build procedure; all kernel
work belongs to the upstream project.
