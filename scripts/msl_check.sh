#!/usr/bin/env bash
# Compile the quoted shaders' MSL (src/ae3d/metal, written by
# tools/generate_shaders.ae from the same trees as their GLSL) with Metal's
# compiler, failing on any warning.
#
#   ./scripts/msl_check.sh [FILE.metal...]   # default: every src/ae3d/metal/*.metal
#
# macOS only. Always through the device's compiler (tools/mslc.m, every
# warning an error); with `xcrun metal` too where the Metal Toolchain is
# installed (xcodebuild -downloadComponent MetalToolchain), -Werror. Exit 0
# when every file compiles clean, 1 when one does not, 2 when it cannot check
# (not macOS, no compiler, no Metal device).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [ "$(uname -s)" != "Darwin" ]; then
    echo "msl_check: Metal is macOS's"
    exit 2
fi
if [ "$#" -gt 0 ]; then files=("$@"); else files=(src/ae3d/metal/*.metal); fi
mkdir -p build
if ! clang -fobjc-arc -O1 -Wall -Wextra -Werror tools/mslc.m -framework Metal -framework Foundation \
        -o build/mslc 2>build/mslc.log; then
    echo "msl_check: tools/mslc.m does not build"
    sed 's/^/    /' build/mslc.log | head -12
    exit 2
fi
./build/mslc "${files[@]}" >build/mslc.out 2>&1
status=$?
if [ "$status" -eq 3 ]; then
    echo "msl_check: no Metal device"
    exit 2
fi
if [ "$status" -ne 0 ]; then
    grep -v ' functions$' build/mslc.out | head -40
    echo "msl_check: Metal's compiler refused the MSL above"
    exit 1
fi
offline="not installed"
if xcrun -sdk macosx metal --version >/dev/null 2>&1; then
    offline="clean"
    for f in "${files[@]}"; do
        if ! xcrun -sdk macosx metal -Werror -c "$f" -o /dev/null 2>build/metal.log; then
            echo "msl_check: xcrun metal: $f"
            sed 's/^/    /' build/metal.log | head -20
            exit 1
        fi
    done
fi
echo "msl_check: ${#files[@]} MSL files compile with every warning an error (xcrun metal: $offline)"
