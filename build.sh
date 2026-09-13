#!/usr/bin/env bash
# Rebuild the SageAttention wheel from the pinned source checkout.
# The wheel stays in src/sageattention/dist/; the consumer installs it.
set -euo pipefail

app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$app_dir/src/sageattention"
venv="$app_dir/src/.venv"
patches="$app_dir/patches"
seed_venv="${SAGEATTENTION_SEED_VENV:-}"
torch_version="2.12.1+cu130"

if [ ! -f "$src/setup.py" ]; then
    echo "error: $src is not initialized; run:" >&2
    echo "  git submodule update --init --depth 1 --checkout sageattention/src/sageattention" >&2
    exit 1
fi

# --- build venv -----------------------------------------------------------
# Seed order: reuse existing; move the venv named in SAGEATTENTION_SEED_VENV
# (one-time migration, avoids re-downloading torch); fresh venv as last resort.
if [ -x "$venv/bin/python" ]; then
    echo "Reusing build venv at $venv"
elif [ -n "$seed_venv" ] && [ -d "$seed_venv" ]; then
    echo "Moving seed venv into place (one-time migration)..."
    mv "$seed_venv" "$venv"
    sed -i "s|$seed_venv|$venv|g" "$venv/pyvenv.cfg"
    find "$venv/bin" -maxdepth 1 -type f -exec sed -i "s|$seed_venv|$venv|g" {} +
else
    echo "Creating fresh build venv (torch download required)..."
    python3.12 -m venv "$venv"
    "$venv/bin/python" -m pip install --upgrade pip wheel setuptools
    "$venv/bin/python" -m pip install "torch==$torch_version" ninja
fi

"$venv/bin/python" -c "import torch; print('torch', torch.__version__, '| cuda', torch.version.cuda)"

# --- patches --------------------------------------------------------------
if grep -q '^#if nvcc_cuda_version' "$src/setup.py"; then
    echo "patch 0001 already applied"
else
    (cd "$src" && git apply "$patches/0001-setup-py-disable-nvcc-cuda-checks.patch")
    echo "patch 0001 applied"
fi

torch_cpp="$venv/lib/python3.12/site-packages/torch/utils/cpp_extension.py"
if grep -q '^#        if cuda_ver.major' "$torch_cpp"; then
    echo "patch 0002 already applied"
else
    (cd "$venv/lib/python3.12/site-packages" && patch -p1 --quiet < "$patches/0002-torch-cpp_extension-allow-cuda-major-mismatch.patch")
    echo "patch 0002 applied"
fi

# --- toolchain -------------------------------------------------------------
# System gcc 16 is too strict for nvcc's front-end over torch 2.12.1
# headers (-Wtemplate-body); nvcc detects the host gcc from PATH, so gcc-15
# shim links go first. torch derives the nvcc -ccbin from CXX.
if command -v g++-15 >/dev/null 2>&1; then
    shim="$venv/.gcc-shim"
    mkdir -p "$shim"
    ln -sf "$(command -v gcc-15)" "$shim/gcc"
    ln -sf "$(command -v g++-15)" "$shim/g++"
    ln -sf "$(command -v g++-15)" "$shim/c++"
    export PATH="$shim:$PATH"
    export CC=gcc-15
    export CXX=g++-15
fi

# --- parallel flags (1-GPU baseline, scaled up by detection) ---------------
# Baseline assumes 1 GPU (4/4/8). Detection uses the build venv torch; when
# it reports more cards, the values scale per GPU (2 cards -> 8/8/16).
# Detection failure or 0 cards keeps the 1-GPU baseline: the CUDA wheel
# build cannot run on a true 0-GPU machine anyway.
gpu_count=$("$venv/bin/python" -c "import torch; print(torch.cuda.device_count())" 2>/dev/null || echo 0)
[ "${gpu_count:-0}" -ge 1 ] || gpu_count=1
export EXT_PARALLEL=$((4 * gpu_count))
export NVCC_APPEND_FLAGS="--threads $((4 * gpu_count))"
export MAX_JOBS=$((8 * gpu_count))
echo "Parallel build flags on (GPUs: $gpu_count, EXT_PARALLEL: $EXT_PARALLEL, MAX_JOBS: $MAX_JOBS)"

# --- wheel -----------------------------------------------------------------
cd "$src" || exit 1
rm -rf build dist ./*.egg-info
"$venv/bin/python" setup.py bdist_wheel
echo "Wheel:"
ls -lh dist/*.whl
