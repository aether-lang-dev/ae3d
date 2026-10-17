#!/bin/sh
# The glslang the checked-in SPIR-V is made with, from Khronos' release.
#
#   ./scripts/glslang.sh [dir]     # prints the directory glslangValidator is in
#
# The SPIR-V in src/ae3d/vkspirv is glslang's output, so it is only
# reproducible from one glslang: 16.6.0 (Nic, 2026-10-16; Debian's 12.0.0 is
# too old to be the reference). generate_shaders refuses any other version,
# and --check compares the SPIR-V it makes against what is checked in, so CI
# needs that exact version, not whatever the runner's packages carry. This
# fetches Khronos' release build into `dir` (default
# ~/.cache/ae3d/glslang-16.6.0), checks the archive's sha256, the binary's
# and the version it reports, and prints its bin directory for PATH:
#
#   PATH="$(./scripts/glslang.sh):$PATH" ./build/generate_shaders --check
#
# A directory that already holds it is used as it is (CI caches it). Linux
# x86_64 only, the runner that runs the check.
set -eu

VERSION=16.6.0
case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)
        asset="glslang-$VERSION-linux-x86_64-release.tar.gz"
        sha="2c34071f56ecf39d16233294d3739cf43f981fd39080f2fd9dccb782101191ce"
        binary_sha="30cdc0e1a09ccfe7164c4b9d3d82bcae6baf759bcd101b053ef087b5c82fade6" ;;
    *)
        # Khronos also builds macOS (universal) and Windows x86_64; Homebrew's
        # glslang is 16.6.0 on a Mac. Only CI's Linux runner is fetched here.
        echo "glslang.sh: no pinned glslang $VERSION download for $(uname -s) $(uname -m) here; install glslang $VERSION and put it on PATH" >&2
        exit 2 ;;
esac

dir="${1:-$HOME/.cache/ae3d/glslang-$VERSION}"
validator="$dir/bin/glslangValidator"

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# The binary Khronos built, by its own sha256 (bin/glslangValidator is a
# link to bin/glslang), and the version it reports.
is_pinned() {
    [ -x "$validator" ] && [ "$(sha256 "$dir/bin/glslang")" = "$binary_sha" ] &&
        "$validator" --version 2>/dev/null | head -1 | grep -q ":$VERSION\$"
}

if ! is_pinned; then
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    curl -fsSL --retry 3 -o "$work/$asset" \
        "https://github.com/KhronosGroup/glslang/releases/download/$VERSION/$asset"
    got="$(sha256 "$work/$asset")"
    if [ "$got" != "$sha" ]; then
        echo "glslang.sh: $asset has sha256 $got, expected $sha" >&2
        exit 1
    fi
    mkdir -p "$dir"
    # glslangValidator is a link to bin/glslang in the archive.
    tar -xzf "$work/$asset" -C "$dir" bin/glslang bin/glslangValidator
    if ! is_pinned; then
        echo "glslang.sh: $validator is not Khronos' $VERSION (sha256 $(sha256 "$dir/bin/glslang"))" >&2
        exit 1
    fi
fi
echo "$dir/bin"
