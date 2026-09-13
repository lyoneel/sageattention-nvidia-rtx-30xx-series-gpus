# Changelog

All notable changes to this project are documented in this file.

## v1.0.0 (unreleased)

Initial public release of the build recipe.

### Added

- Pinned build of SageAttention 2.1.1 (upstream commit
  `7688d781fa6022649daacf6b9c4ad267c83df6b4`) targeting NVIDIA
  RTX 30-series GPUs (compute capability 8.6).
- `build.sh`: single entry point with venv seeding, idempotent patch
  application, gcc-15 compiler shim, and `bdist_wheel` output.
- Patch series: NVCC version check removal in `setup.py`, and CUDA
  major mismatch tolerance in torch `cpp_extension.py`.
- GPU-scaled parallel build flags: 1-GPU baseline (4, 4, 8), scaled
  by detected GPU count.
- README with usage, compatibility, and known issues.
