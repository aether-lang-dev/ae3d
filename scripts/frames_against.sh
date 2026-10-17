#!/usr/bin/env bash
# This tree's frames against another commit's, on this machine's GPU.
#
#   ./scripts/frames_against.sh [ref]          # ref defaults to origin/main
#
# A shader moved from hand-written GLSL to a quoted one (docs/aether_quote_design.md)
# should draw the same frames it drew before. This builds test_backend_parity
# and zombie_city here and in a worktree of `ref`, draws the same frames in
# both, and compares them with tools/frame_diff:
#
#   - every case test_backend_parity dumps (AE3D_PARITY_DUMP), OpenGL and Vulkan;
#   - zombie_city held at frame 90, at one sample and at the default (4x on
#     Vulkan), on Vulkan, and at one sample on OpenGL.
#
# Exactly, byte for byte, except the two scenes that are not the same twice on
# the same commit, which get the tolerance their issue measured, plus room,
# until the issue is fixed:
#
#   - clouds_over_the_skybox (#793): runs on main differ in 2,016 to 2,066
#     channels of 147,456, by 25 (OpenGL) to 33 (Vulkan) steps of 255 at the
#     worst. Held to 40 steps on at most 4,000 channels.
#   - zombie_city (#794): at one sample it falls into one of several frames,
#     on both renderers: the runs in one agree within 52 to 107 channels,
#     worst 4, the others are 1,800 to 42,000 channels away, worst up to
#     146, and a third to two thirds of runs land in any one; at 4x, 19
#     channels, worst 1. Each frame is drawn CITY_DRAWS (5) times on each
#     side and the closest pair is held to 4 steps on at most 400 channels,
#     so another mode does not fail a change that did not cause it.
#
# Each tree is built with the Aether release it pins (AETHER_REF in its
# .github/workflows/ci.yml). One toolchain for both drew nothing on Vulkan
# when the pins differed: a release that names a quote's helpers otherwise
# (aether#2943) hashes the other tree's quoted shaders otherwise, and its
# Vulkan refuses their SPIR-V. A pin the toolchain on PATH is gets that one;
# another is built once from an Aether checkout (AE3D_AETHER_SRC, ../aether
# by default) at its tag, under build/frames_against/aether-<tag>. With no
# checkout, or no such tag in it, this says so and stops (exit 2) rather
# than compare frames from the wrong compiler.
#
# Exits 0 when every frame matches, 1 naming those that do not, 2 when
# something could not be built or drawn. Needs a GPU (a software rasteriser
# draws it too, slowly); the frames are kept under build/frames_against/ to
# be looked at.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
REF="${1:-origin/main}"
OUT="$ROOT/build/frames_against"
THERE="$OUT/ref"

# The tolerances, (within, over): no channel past `within`, no more than `over`
# channels differing at all.
CLOUDS_WITHIN=40
CLOUDS_OVER=4000
CITY_WITHIN=4
CITY_OVER=400
CITY_DRAWS="${AE3D_CITY_DRAWS:-5}"

rm -rf "$OUT/here" "$OUT/there"
mkdir -p "$OUT/here" "$OUT/there"
# `ref` as this checkout names it: in the worktree HEAD is its own.
commit="$(git rev-parse --verify "$REF^{commit}")" || exit 2
if [ ! -d "$THERE/.git" ] && [ ! -f "$THERE/.git" ]; then
    git worktree add --detach "$THERE" "$commit" >/dev/null || exit 2
fi
git -C "$THERE" checkout --quiet --detach "$commit" || exit 2
# The physics engine at the commit `ref` names, cloned from this checkout's
# own copy so nothing is fetched.
want="$(git -C "$THERE" rev-parse HEAD:deps/aephysics)"
if [ "$(git -C "$THERE/deps/aephysics" rev-parse HEAD 2>/dev/null)" != "$want" ]; then
    rm -rf "$THERE/deps/aephysics"
    git clone --quiet --no-checkout "$(git rev-parse --git-path modules/deps/aephysics)" "$THERE/deps/aephysics" || exit 2
    git -C "$THERE/deps/aephysics" checkout --quiet "$want" || exit 2
fi

# The Aether release a tree pins, as its CI builds it.
pin_of() {  # pin_of <tree>
    sed -n 's/^  AETHER_REF: *//p' "$1/.github/workflows/ci.yml" | head -1
}
# The release the toolchain on PATH is (v0.821.0), or nothing.
ON_PATH="$(aetherc --version 2>/dev/null | sed -n 's/.* v\([0-9][0-9.]*\).*/v\1/p')"
AETHER_SRC="${AE3D_AETHER_SRC:-$ROOT/../aether}"

# The directory of an Aether built at `pin`, printed; "" for the one on PATH.
# Built once, from AETHER_SRC at the tag, and kept.
toolchain_for() {  # toolchain_for <pin>
    if [ -z "$1" ] || [ "$1" = "$ON_PATH" ]; then
        echo ""
        return 0
    fi
    local dir="$OUT/aether-$1"
    if [ ! -x "$dir/build/aetherc" ]; then
        if ! git -C "$AETHER_SRC" rev-parse --verify --quiet "$1^{commit}" >/dev/null 2>&1; then
            echo "frames_against: a tree pins Aether $1, the toolchain on PATH is ${ON_PATH:-none}," >&2
            echo "  and $AETHER_SRC has no $1 to build it from (AE3D_AETHER_SRC names an aether" >&2
            echo "  checkout; git -C it fetch --tags)" >&2
            return 2
        fi
        rm -rf "$dir"
        git -C "$AETHER_SRC" worktree add --detach "$dir" "$1" >/dev/null 2>&1 || return 2
        echo "frames_against: building Aether $1 for a tree that pins it" >&2
        make -C "$dir" -j"$(nproc 2>/dev/null || echo 4)" >"$OUT/aether-$1.log" 2>&1 || {
            echo "frames_against: Aether $1 did not build (see $OUT/aether-$1.log)" >&2
            return 2
        }
    fi
    echo "$dir"
}

build() {   # build <tree>: the programs this draws with, by the Aether it pins
    local pin dir
    pin="$(pin_of "$1")"
    dir="$(toolchain_for "$pin")" || exit 2
    echo "frames_against: $1 with Aether ${pin:-as on PATH}${dir:+ (built at $dir)}"
    for program in tests/test_backend_parity.ae examples/zombie_city.ae tools/ae3d_agent.ae; do
        if [ -n "$dir" ]; then
            (cd "$1" && PATH="$dir/build:$PATH" AETHER_HOME="$dir" ./build.sh "$program" >"$OUT/build.log" 2>&1)
        else
            (cd "$1" && ./build.sh "$program" >"$OUT/build.log" 2>&1)
        fi || {
            echo "frames_against: $program did not build in $1"
            tail -5 "$OUT/build.log"
            exit 2
        }
    done
}
(cd "$ROOT" && ./build.sh tools/frame_diff.ae >"$OUT/build.log" 2>&1) || { echo "frames_against: frame_diff did not build"; exit 2; }
build "$ROOT"
build "$THERE"

# snap <tree> <png> <port> <api> [msaa]: zombie_city held at frame 90, snapshotted.
snap() {
    (
        cd "$1" || exit 2
        env ${5:+AE3D_MSAA=$5} AE3D_TICK=60 AE3D_HOLD=90 AE3D_AGENT="$3" AE3D_HIDDEN=1 AE3D_API="$4" \
            AE3D_WIDTH=320 AE3D_HEIGHT=180 ./build/zombie_city >"$2.log" 2>&1 &
        pid=$!
        i=0
        while [ $i -lt 600 ]; do
            ./build/ae3d_agent --port "$3" frame.stats 2>/dev/null | grep -q '"frame":90,.*"paused":true' && break
            sleep 0.5
            i=$((i + 1))
        done
        ./build/ae3d_agent --port "$3" snapshot path="$2" >"$2.agent.log" 2>&1
        status=$?
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        exit $status
    )
}

draw() {   # draw <tree> <dir>
    (cd "$1" && AE3D_PARITY_DUMP="$2" ./build/test_backend_parity >"$2/parity.log" 2>&1)
    mkdir -p "$2/city"
    k=1
    while [ "$k" -le "$CITY_DRAWS" ]; do
        snap "$1" "$2/city/vk_1_$k.png" 7951 vulkan 0 || echo "frames_against: zombie_city (vulkan, 1 sample) in $1 did not answer"
        snap "$1" "$2/city/vk_$k.png" 7952 vulkan || echo "frames_against: zombie_city (vulkan) in $1 did not answer"
        snap "$1" "$2/city/gl_1_$k.png" 7953 opengl 0 || echo "frames_against: zombie_city (opengl, 1 sample) in $1 did not answer"
        k=$((k + 1))
    done
}
draw "$ROOT" "$OUT/here"
draw "$THERE" "$OUT/there"

compared=0
differ=0
for frame in "$OUT/there"/*.png; do
    name="$(basename "$frame")"
    tolerance=""
    case "$name" in
        clouds_over_the_skybox_*) tolerance="--within $CLOUDS_WITHIN --over $CLOUDS_OVER" ;;
    esac
    if [ ! -f "$OUT/here/$name" ]; then
        echo "   FAIL  $name: drawn by $REF, not here"
        differ=$((differ + 1))
        continue
    fi
    compared=$((compared + 1))
    # shellcheck disable=SC2086
    if verdict="$(./build/frame_diff "$frame" "$OUT/here/$name" $tolerance)"; then
        [ -n "$tolerance" ] && echo "   ok    $name: $verdict"
    else
        echo "   FAIL  $name: $verdict"
        differ=$((differ + 1))
    fi
done
# zombie_city (#794): the closest of its draws here to any of the ref's.
for mode in vk_1 vk gl_1; do
    best=""
    for there in "$OUT/there/city/${mode}_"[0-9]*.png; do
        [ -f "$there" ] || continue
        for here in "$OUT/here/city/${mode}_"[0-9]*.png; do
            [ -f "$here" ] || continue
            if verdict="$(./build/frame_diff "$there" "$here" --within "$CITY_WITHIN" --over "$CITY_OVER")"; then
                best="$verdict"
                break 2
            fi
            [ -z "$best" ] && best="FAIL $verdict"
        done
    done
    compared=$((compared + 1))
    case "$best" in
        "") echo "   FAIL  zombie_city $mode: not drawn"; differ=$((differ + 1)) ;;
        FAIL*) echo "   FAIL  zombie_city $mode: no draw here within $CITY_WITHIN on $CITY_OVER of any of $REF's (${best#FAIL })"; differ=$((differ + 1)) ;;
        *) echo "   ok    zombie_city $mode: $best" ;;
    esac
done
if [ "$compared" -eq 0 ]; then
    echo "frames_against: no frames were drawn (see $OUT/*/parity.log)"
    exit 2
fi
echo "frames_against: $compared frames against $REF ($(git -C "$THERE" rev-parse --short HEAD)), $differ differ"
[ "$differ" -eq 0 ]
