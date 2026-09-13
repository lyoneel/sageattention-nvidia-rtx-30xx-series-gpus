# Contributing to sageattention-nvidia-rtx-30xx-series-gpus

Thank you for considering a contribution. This repository packages a
build procedure for the SageAttention wheel. Keep changes small and
testable.

## Dev setup

```bash
git clone https://github.com/thu-ml/SageAttention.git src/sageattention
git -C src/sageattention checkout 7688d781fa6022649daacf6b9c4ad267c83df6b4
./build.sh
```

Requirements: python 3.12, CUDA toolkit with nvcc, and an NVIDIA
RTX 30-series GPU. See the README for the full table.

## Code style

1. Bash only, `set -euo pipefail` at the top of every script.
2. Use `#!/usr/bin/env bash` shebangs.
3. Resolve paths from the script location, never from the working
   directory.
4. Keep the script idempotent: check the patched or generated state
   before creating it.
5. Run `bash -n` and `shellcheck` before every commit.

## Testing

The project has no runtime test suite. Verification steps:

1. `bash -n build.sh` for syntax.
2. `shellcheck build.sh` for static analysis.
3. A wheel appears in `src/sageattention/dist/` after a build.
4. `python -c "import sageattention"` succeeds in a consumer venv
   with a matching torch.

## Commit and pull request process

1. Use conventional commit messages (`feat:`, `fix:`, `docs:`,
   `chore:`), one logical change per commit.
2. Describe why the change is needed, not only what it does.
3. Pull requests must state the GPU and toolchain used for testing.

## Patch series

1. Name patches `NNNN-short-kebab-description.patch` in application
   order.
2. Verify each new patch with `git apply --check` against the pin.
3. Never commit the patched source tree.

## License

All contributions are submitted under the MIT license. See
[LICENSE](LICENSE).
