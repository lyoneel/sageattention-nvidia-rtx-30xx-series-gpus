# AGENTS.md

Developer reference for agents and maintainers working on this
repository. The README is the user-facing document; this file adds
the internal view. Do not duplicate README content here.

## What this repository is

A build recipe for the SageAttention wheel. It pins the upstream
source, applies a patch series, and produces a wheel through one
script. It contains no kernel code; all kernel work lives upstream.

## Layout

| Path | Role |
|------|------|
| `recipe.md` | Build contract: pin, environment, steps, patches, known issues |
| `build.sh` | Single rebuild entry point |
| `patches/` | Ordered patch series, applied by `build.sh` |
| `README.md` | User-facing overview and usage |

## Build flow

1. The caller provides the source checkout at `src/sageattention`
   (clone of the upstream repo at the recorded pin).
2. `build.sh` resolves its own location (`app_dir`), so it runs from
   any working directory.
3. Venv seeding order: reuse `src/.venv`; else move the venv named in
   `SAGEATTENTION_SEED_VENV` (path rewrite included); else create a
   fresh venv with the declared torch.
4. Patch application is idempotent: `build.sh` greps for the patched
   state before each apply.
5. Parallel flags use a 1-GPU baseline (4, 4, 8) and scale with the
   GPU count that torch reports (2 cards give 8, 8, 16).
6. The wheel lands in `src/sageattention/dist/`.

## Patch series rules

1. Files are named `NNNN-short-kebab-description.patch` in
   application order.
2. A new patch must pass `git apply --check` against the recorded pin
   before it lands here.
3. Never commit patched state inside a source checkout; the dirty
   tree after patching is the expected state.

## Verification

```bash
bash -n build.sh
shellcheck build.sh
```

Test the parallel-flag logic with a stubbed `python` that prints the
GPU count you want (0, 1, 2, 4) and confirm the scaled values.

## Known issue

The recorded pin cannot be rebuilt against torch 2.12.1 with nvcc
13.3. See the Known issues section in `recipe.md` before planning a
rebuild.
