#!/usr/bin/env bash
# Build and run everything: the native layer, every module, every test suite and
# every example.
#
# Examples need a window, so they are driven for a bounded number of frames via
# AE3D_FRAMES and are skipped where no display is available.
#
#   ./ci.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

FRAMES="${AE3D_CI_FRAMES:-30}"
# The examples are a build-and-run smoke test: does each one start, render and
# survive a few frames without crashing. That is answered in the first handful
# of frames -- init, the first draw, the loop settling -- and the behaviour and
# look of the engine are proved at depth elsewhere, by the test suites and by
# the demo scene's own critique, neither of which this touches. Two examples are
# heavy per frame on the software rasteriser a headless runner falls back to
# (sand alone spent minutes of a nine-minute run at
# thirty frames each); a smoke depth of ten keeps the coverage and gives that
# time back.
EXAMPLE_FRAMES="${AE3D_CI_EXAMPLE_FRAMES:-10}"

# The size suites and examples draw at. A runner has no GPU, and a software
# rasteriser is billed for every pixel it shades: the same run at a quarter of
# the width and a quarter of the height does every frame, every draw and every
# branch of the shader for a sixteenth of the work. Three examples were 68% of
# this file's wall time on Linux for that reason alone.
#
# Benchmarks are exempt: what they measure is the cost of a frame, and a frame
# is a size.
export AE3D_WIDTH="${AE3D_CI_WIDTH:-320}"
export AE3D_HEIGHT="${AE3D_CI_HEIGHT:-180}"
# Every frame is still drawn; none of them reaches a screen. On a runner with a
# display this file used to open and close dozens of windows, each one a chance
# to take focus from whatever else the machine was doing, and none of them was
# ever looked at -- what the examples are judged on comes back over the channel.
export AE3D_HIDDEN="${AE3D_HIDDEN:-1}"
failures=0
skipped=0

step() { printf '\n== %s\n' "$1"; }
pass() { printf '   ok    %s\n' "$1"; }
fail() { printf '   FAIL  %s\n' "$1"; failures=$((failures + 1)); }
skip() { printf '   skip  %s (%s)\n' "$1" "$2"; skipped=$((skipped + 1)); }

have_display() {
    case "$(uname -s)" in
        Darwin) return 0 ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT) return 0 ;;
        *) [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ] ;;
    esac
}

# What a run covers (#511). ./ci.sh with no tier -- the gate on the machine a
# change is written on -- runs everything. A runner runs the tier its
# platform is there for, named in the workflow's matrix, since each of the
# three is paid for by the minute and almost all of a minute is compiling:
#   full      Linux: suites and apps below, on one machine
#   suites    Linux: every suite, the Vulkan validation layer, the checks of
#             what is generated from the tree, the benchmarks' smoke run
#   apps      Linux: the examples and the editor
#   leaks     macOS: every suite, each held to `leaks`
#   platform  Windows: the suites over code that differs by platform --
#             sockets, threads, files and formats, float rounding, scripts
# The showcase scenes are the local gate's (scripts/ci_scenes.sh); a runner
# runs them only with AE3D_CI_SCENES=1.
TIER="${AE3D_CI_TIER:-all}"
case "$TIER" in
    all|full|suites|apps|leaks|platform) ;;
    *) echo "ci: unknown AE3D_CI_TIER '$TIER' (all, full, suites, apps, leaks or platform)" >&2; exit 2 ;;
esac
SCENES="${AE3D_CI_SCENES:-}"
[ "$TIER" = all ] && SCENES=1
in_tier() {   # in_tier <tier>...: whether this run covers any of them
    [ "$TIER" = all ] && return 0
    for wanted in "$@"; do
        [ "$TIER" = "$wanted" ] && return 0
        # Linux's share is two runners at once on the workflow, suites and
        # apps, each about half of what one runner took end to end; full is
        # the same share on one machine.
        if [ "$TIER" = full ]; then
            case "$wanted" in suites|apps) return 0 ;; esac
        fi
    done
    return 1
}
PLATFORM_SUITES="test_net test_net_authority test_net_budget test_net_delta
    test_net_events test_net_fields test_net_handover test_net_horde
    test_net_sight test_net_udp test_players test_agent test_agent_net
    test_jobs test_assets test_obj_cache test_image_decode test_gltf
    test_loader test_scene_io test_font test_determinism test_gmath
    test_script"
# The suites that draw: each needs a window, a GL context or a Vulkan device,
# and says SKIP where there is none. The macOS and Windows runners have none
# (run 36919172954: these 61 skipped on macOS), so there each was built --
# the whole engine compiled again, four of the macOS job's minutes in all --
# to print SKIP and be held to `leaks` on the way out. AE3D_CI_GPU=0, which the
# workflow sets on those runners, builds none of them. A suite left off this
# list is built and skips as before: forgetting one costs time, not coverage.
GPU_SUITES="test_agent test_agent_attached test_agent_components test_agent_explain
    test_agent_net test_agent_record test_backend_parity test_batching
    test_blackhole test_camera_collision test_caustics test_character test_cluster_cut
    test_crowd_ecs test_crowd_render test_crowd_render_scale
    test_culling test_damage test_depth_clear test_depth_proxy test_device_crowd
    test_dlss test_ecs_render test_engine_shadows test_engine_skybox
    test_figure test_fog test_gameobjects test_gi test_gltf_crowd test_hdr test_hierarchy
    test_hud_layout test_impostor test_instance_colours test_instance_positions test_interpolation
    test_instance_streams test_instances test_lamp_clusters
    test_lamp_shadows test_lights test_mesh_edit test_model_mesh
    test_motion test_offscreen test_overlay test_physics
    test_ray_occlusion test_ray_shadows test_readback_buffers
    test_render test_render_scale test_scene_hold test_shading_isolation
    test_shading_knobs test_shadow_batches test_shadow_cascades test_sky_light
    test_shadows test_skinned_render test_ssr test_taa test_texture_swap
    test_trace test_velocity test_vk_mesh test_weather"
suite_sources() {   # the suites this tier builds and runs
    for suite in tests/test_*.ae; do
        name="$(basename "$suite" .ae)"
        if [ "$TIER" = platform ]; then
            case " $(echo $PLATFORM_SUITES) " in *" $name "*) ;; *) continue ;; esac
        fi
        if [ "${AE3D_CI_GPU:-1}" = 0 ]; then
            case " $(echo $GPU_SUITES) " in *" $name "*) continue ;; esac
        fi
        echo "$suite"
    done
}

# A suite, example or benchmark that hangs should fail this step by name rather
# than stall the job until the runner's own six-hour limit: one did, on Linux,
# for three and a half hours, and the log said nothing at all. Not every
# platform ships coreutils' timeout, so where it is missing the run is
# unguarded, exactly as it was before.
if command -v timeout >/dev/null 2>&1; then
    bounded() { timeout "$@"; }
else
    bounded() { shift; "$@"; }
fi
RUN_LIMIT="${AE3D_CI_RUN_LIMIT:-300}"

# A shell gives 128 plus the signal for a child that was killed, and the
# message a crash leaves on its own says neither which signal nor which suite.
# Every target is built the same way and none of them depend on another, so
# they are built at once and run one at a time: builds are the whole of the
# Windows leg, where most suites skip for want of a GPU, and running in
# parallel would have several programs contending for one software rasteriser
# and report timings nobody can read.
JOBS="${AE3D_CI_JOBS:-$( (nproc || sysctl -n hw.ncpu) 2>/dev/null || echo 2 )}"
export BUILD_DIR="${TMPDIR:-/tmp}/ae3d_builds"

# in_pool <function> <arg>...: the function once for each argument, JOBS at a
# time, the next starting the moment any one ends. They were started JOBS at a
# time and waited for JOBS at a time, so every batch took as long as its
# slowest member and the other cores sat idle until it was done: a whole-engine
# build of one suite is several times another's. xargs -P is the pool, since
# `wait -n` needs bash 4.3 and macOS ships 3.2; the function and what it
# reads are exported to the shells it starts.
in_pool() {
    pool_fn="$1"
    shift
    [ $# -gt 0 ] || return 0
    export -f "$pool_fn"
    printf '%s\n' "$@" | xargs -n 1 -P "$JOBS" "$BASH" -c "$pool_fn \"\$1\"" _ || true
}

build_one() {   # build_one <source>: its log and its status, under BUILD_DIR
    target="$(basename "$1" .ae)"
    ./build.sh "$1" "$target" >"$BUILD_DIR/$target.log" 2>&1
    echo $? >"$BUILD_DIR/$target.status"
}

build_together() {   # build_together <source> [<source>...]
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    # The C half once, up front: every build below would otherwise race to
    # compile the same objects into the same files.
    ./build.sh --natives >"$BUILD_DIR/natives.log" 2>&1 || true
    pool_started=$SECONDS
    in_pool build_one "$@"
    build_costs $((SECONDS - pool_started))
}

# build_costs <wall seconds>: what the pool just spent, from each build's last
# line, so a run's log says where its minutes went rather than only how many
# there were: the sum of each phase over every target, and the slowest three.
build_costs() {
    cat "$BUILD_DIR"/*.log 2>/dev/null | awk -v wall="$1" -v jobs="$JOBS" '
        /^built: .*\(aetherc [0-9]+ s, cc [0-9]+ s, link [0-9]+ s\)$/ {
            n++; a += $(NF-7); c += $(NF-4); l += $(NF-1)
            name = $2; sub(/.*\//, "", name)
            total = $(NF-7) + $(NF-4) + $(NF-1)
            print total, name > "/dev/stderr"
        }
        END {
            if (n) printf "        built %d in %d s, %d at a time: aetherc %d s, cc %d s, link %d s in all\n", n, wall, jobs, a, c, l
        }' 2>"$BUILD_DIR/costs"
    if [ -s "$BUILD_DIR/costs" ]; then
        printf '        slowest:'
        sort -rn "$BUILD_DIR/costs" | head -3 | awk '{ printf " %s %d s", $2, $1 }'
        printf '\n'
    fi
}

# What build_together made of one target: 0 and a quiet log, or the reason.
built_ok() {   # built_ok <name>
    [ "$(cat "$BUILD_DIR/$1.status" 2>/dev/null || echo 1)" = "0" ]
}

died_on() {   # died_on <status>
    if [ "$1" -gt 128 ] && [ "$1" -lt 160 ]; then
        printf ' (died on signal %d)' "$(($1 - 128))"
    fi
}

# A crash on a headless runner leaves only "died on signal 11". When the status
# is a signal and gdb is present, run the program again under it and print the
# native stack, so the log names the frame that fell over instead of a core
# file nobody can open. Off unless AE3D_CI_TRACE is set, since it re-runs a
# crashing program.
trace_crash() {   # trace_crash <status> <binary> [args...]
    [ -n "${AE3D_CI_TRACE:-}" ] || return 0
    trace_status="$1"; shift
    [ "$trace_status" -gt 128 ] && [ "$trace_status" -lt 160 ] || return 0
    command -v gdb >/dev/null 2>&1 || return 0
    echo "        --- native stack (gdb) ---"
    AE3D_FRAMES="${FRAMES:-3}" gdb -batch -nx \
        -ex run -ex bt -ex quit --args "$@" 2>&1 \
        | grep -E '^#[0-9]+|Program received|signal SIG' | sed 's/^/        /' | head -25
}

. "$PWD/scripts/native.sh"

# A PNG's size, without a decoder: the IHDR width and height are two big-endian
# 32-bit words at a fixed offset, after the signature and the chunk header.
# od's -j, -N and -t x1 are POSIX, so this reads the same on macOS; the
# words are put together by hand since --endian is GNU-only.
snapshot_size() {
    set -- $(od -An -t x1 -j 16 -N 8 "$1" 2>/dev/null)
    [ $# -eq 8 ] || return 0
    echo "$((0x$1$2$3$4))x$((0x$5$6$7$8))"
}

snapshot_is() {
    [ -n "$2" ] || return 0
    [ "$(snapshot_size "$1")" = "$2" ]
}

step "platform link libraries"
# Every host this can be built on, checked from any host. Windows had no arm
# at all and the catch-all's -lm cannot link an OpenGL program, so ae3d could
# not be linked there however complete the install was (#80). A missing arm is
# invisible from the machine that does not need it, which is why this runs
# everywhere rather than only where it applies.
. "$ROOT/scripts/platform.sh"
check_platform() {   # check_platform <uname> <library that must be there>
    libs="$(ae3d_platform_libs "$1")"
    case "$libs" in
        *"$2"*) pass "uname=$1 links $2" ;;
        *)      fail "uname=$1 does not link $2 (got: $libs)" ;;
    esac
}
check_platform Darwin            "-framework OpenGL"
check_platform Linux             "-ldl"
check_platform MINGW64_NT-10.0   "-lopengl32"
check_platform MINGW64_NT-10.0   "-lgdi32"
check_platform MSYS_NT-10.0      "-lopengl32"
check_platform Windows_NT        "-lopengl32"

step "the agent channel stays behind its gate"
# The one property the channel's whole design rests on, and the one thing a
# timing test cannot check: an ungated hook is a change to the source, not a
# state at run time. See scripts/check_agent_gating.sh.
./scripts/check_agent_gating.sh 2>/tmp/ae3d_gate.log
gate_status=$?
if [ "$gate_status" -eq 0 ]; then
    pass "engine_loop reaches the agent only through e.agent_on"
elif [ "$gate_status" -eq 1 ]; then
    fail "engine_loop reaches the agent outside the gate"
    sed "s/^/        /" /tmp/ae3d_gate.log | head -10
else
    # 126 is "not executable", 127 is "not found". Reporting either as an
    # ungated hook names a bug that is not there and hides the one that is.
    fail "check_agent_gating.sh could not run (exit $gate_status)"
    sed "s/^/        /" /tmp/ae3d_gate.log | head -5
fi

step "exported fixtures match the exporter"
# Catches an exporter change that nobody regenerated the fixtures for. The
# committed assets under tests/fixtures/exported/ are what test_assets runs
# against on machines with no Blender, so they have to be what this exporter
# actually produces rather than what it produced once.
#
# Skips where Blender is absent, which is most CI.
if command -v blender >/dev/null 2>&1 || [ -n "${BLENDER:-}" ]; then
    check_exported() {   # check_exported <blend> <committed directory>
        fresh="$(mktemp -d)"
        ./scripts/export_assets.sh "$1" "$fresh" >/tmp/ae3d_export.log 2>&1
        if [ ! -f "$fresh/manifest.json" ]; then
            skip "$2" "the exporter produced nothing (see /tmp/ae3d_export.log)"
        elif diff -r "$2" "$fresh" >/tmp/ae3d_export_diff.log 2>&1; then
            pass "$2 is what the exporter produces"
        else
            fail "$2 is stale; run ./scripts/export_assets.sh"
            sed 's/^/        /' /tmp/ae3d_export_diff.log | head -10
        fi
        rm -rf "$fresh"
    }
    check_exported tests/fixtures/spin.blend tests/fixtures/exported
    check_exported resources/blender/showcase.blend resources/blender/showcase
    check_exported resources/blender/zombie_street.blend resources/blender/zombie_street
    check_exported resources/blender/car.blend resources/blender/car
else
    skip "exported fixtures" "no Blender"
fi

if in_tier suites; then
step "no two surfaces share a plane"
# Z-fighting is two faces in one plane close enough in depth that rounding
# decides which is in front. Looked for on screen it depends on where the
# camera happens to be; looked for in the geometry, either two faces share a
# plane and overlap or they do not. Runs against the committed export, so it
# needs no Blender.
if ! ./build.sh tools/check_coplanar.ae >/tmp/ae3d_coplanar.log 2>&1; then
    fail "check_coplanar (build)"
    sed 's/^/        /' /tmp/ae3d_coplanar.log | head -12
else
    for exported in resources/blender/zombie_street resources/blender/showcase resources/blender/car; do
        if ./build/check_coplanar "$exported" >/tmp/ae3d_coplanar.log 2>&1; then
            pass "$exported has no coplanar overlaps"
        else
            fail "$exported has surfaces that would fight over the same depth"
            sed 's/^/        /' /tmp/ae3d_coplanar.log | head -12
        fi
    done
fi

step "every window pane faces the street"
# A pane is one sheet drawn from its front: one wound into its building is
# culled from the street, and the window is a hole onto the hollow shell
# behind it (#478). Read back from the committed export, so no Blender.
if ! ./build.sh tools/check_panes.ae >/tmp/ae3d_panes.log 2>&1; then
    fail "check_panes (build)"
    sed 's/^/        /' /tmp/ae3d_panes.log | head -12
elif ./build/check_panes resources/blender/zombie_street >/tmp/ae3d_panes.log 2>&1; then
    pass "resources/blender/zombie_street's panes all face out"
else
    fail "resources/blender/zombie_street has panes facing into their buildings"
    sed 's/^/        /' /tmp/ae3d_panes.log | head -12
fi

step "docs/agent.md matches the engine's command table"
# A doc written by hand beside a protocol is a doc that describes last month's
# protocol. This one is generated from the same table `help` answers with, so
# the check is that it was regenerated after the table changed.
./scripts/gen_agent_docs.sh --check >/tmp/ae3d_docs.log 2>&1
docs_status=$?
if [ "$docs_status" -eq 0 ]; then
    pass "docs/agent.md is what the schema produces"
elif [ "$docs_status" -ne 1 ]; then
    # Anything but 1 is "could not check": 2 from the script itself, 126 when
    # it is not executable, 127 when it is not there. Only 1 means the page
    # and the schema actually disagree.
    skip "docs/agent.md" "$(head -1 /tmp/ae3d_docs.log)"
else
    fail "docs/agent.md is out of date; run ./scripts/gen_agent_docs.sh"
    sed "s/^/        /" /tmp/ae3d_docs.log | head -12
fi

# The Vulkan shaders are generated from the GLSL in src/ae3d/shaders and
# checked in. An edit to the GLSL without the generator run after it leaves
# Vulkan on the previous shader, which fails parity in ways that look like
# real bugs; the check is that the checked-in files are what the source makes.
step "Vulkan shaders regenerated"
if ! ./build.sh tools/generate_shaders.ae >/tmp/ae3d_shaders.log 2>&1; then
    fail "generate_shaders (build)"
    sed "s/^/        /" /tmp/ae3d_shaders.log | head -12
elif ./build/generate_shaders --check >/tmp/ae3d_shaders.log 2>&1; then
    pass "src/ae3d/vkspirv/glsl and vkscene are what src/ae3d/shaders produces"
else
    fail "generated Vulkan shaders are out of date; run build/generate_shaders"
    sed "s/^/        /" /tmp/ae3d_shaders.log | head -12
fi

fi

step "native layer, warnings as errors"
# Same compiler search as build.sh: a Windows toolchain need not ship `cc`.
if [ -z "${CC:-}" ]; then
    for candidate in cc gcc clang; do
        if command -v "$candidate" >/dev/null 2>&1; then CC="$candidate"; break; fi
    done
fi
CC="${CC:-cc}"
# The flags build.sh and the editor's build use, from the same functions: a
# probe of its own here found GLFW only through pkg-config and Vulkan never
# through the SDK, so the native step could fail on a machine every other
# step built on (#408).
. "$ROOT/scripts/native.sh"
ae3d_glfw_flags
ae3d_vulkan_flags
for src in native/*/*.c; do
    if "$CC" -c -O2 $(ae3d_fp_flags) -Wall -Wextra -Werror $GLFW_CFLAGS $VULKAN_CFLAGS "$src" -o /dev/null 2>/tmp/ae3d_cc.log; then
        pass "$src"
    else
        fail "$src"
        sed 's/^/        /' /tmp/ae3d_cc.log | head -20
    fi
done
if [ "$(uname -s)" = "Darwin" ]; then
    if "$CC" -c -O2 $(ae3d_fp_flags) -Wall -Wextra -Werror -fobjc-arc $GLFW_CFLAGS native/platform/metal_surface.m -o /dev/null 2>/tmp/ae3d_cc.log; then
        pass "native/platform/metal_surface.m"
    else
        fail "native/platform/metal_surface.m"
        sed 's/^/        /' /tmp/ae3d_cc.log | head -20
    fi
fi

# One runner of Linux's two is enough to say a module stopped compiling; the
# apps half would only say it again.
if in_tier suites leaks platform; then
step "modules type-check"
for module in src/ae3d/*/; do
    name="$(basename "$module")"
    probe="$(mktemp -t ae3d_probe.XXXXXX).ae"
    printf 'import ae3d.%s\nmain() { println("ok") }\n' "$name" > "$probe"
    # The same search path build.sh gives every program: the engine, and
    # the physics engine in its submodule, which ae3d.physics imports.
    if AETHER_LIB_DIR="$PWD/src:$PWD/deps/aephysics" aetherc "$probe" "${probe%.ae}.c" >/tmp/ae3d_mod.log 2>&1; then
        pass "ae3d.$name"
    else
        fail "ae3d.$name"
        sed 's/^/        /' /tmp/ae3d_mod.log | head -10
    fi
    rm -f "$probe" "${probe%.ae}.c"
done

# Shared code belonging to the examples, outside the engine's namespace and
# imported by its path from the root (examples.lib.<name>), as the examples
# import it. Type-checked the same way: a module that stops compiling
# should fail here, rather than three lines later in whichever example happens to
# get built first.
for module in examples/lib/*/; do
    [ -e "$module" ] || continue
    name="$(basename "$module")"
    probe="$(mktemp -t ae3d_probe.XXXXXX).ae"
    printf 'import examples.lib.%s\nmain() { println("ok") }\n' "$name" > "$probe"
    if AETHER_LIB_DIR="$PWD/src" aetherc "$probe" "${probe%.ae}.c" >/tmp/ae3d_mod.log 2>&1; then
        pass "examples/lib/$name"
    else
        fail "examples/lib/$name"
        sed 's/^/        /' /tmp/ae3d_mod.log | head -10
    fi
    rm -f "$probe" "${probe%.ae}.c"
done
fi

# The scripts an object can be given. They are built before the suites because
# a script is a separate library the test opens at runtime rather than
# something linked into it, which is the whole point of one.
step "scripts"
for script_source in resources/scripts/*.ae; do
    [ -e "$script_source" ] || continue
    script_name="$(basename "$script_source" .ae)"
    if ! ./scripts/build_script.sh "$script_source" >/tmp/ae3d_script.log 2>&1; then
        fail "script $script_name"
        sed 's/^/        /' /tmp/ae3d_script.log | head -10
        continue
    fi
    # A script reaches into the engine the host is running, never a copy of its
    # own: two copies of the GL loader means a script drawing through function
    # pointers nothing ever filled in. It links the same library the host does,
    # and this is where that is checked rather than trusted.
    script_lib="build/scripts/$script_name$(ae3d_native_suffix)"
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            # nm alone cannot answer it here. Linking against an import library
            # leaves a thunk in .text under the imported name, and a DLL that
            # exports nothing explicitly exports those too, so every imported
            # call reads as a definition. So: a script that imports the engine
            # library gets its C from there; one that does not must have none
            # of the engine's C in it at all. (A script that calls only what is
            # Aether now -- the mesh and instance stores, since #398 -- needs no
            # native call and imports no engine library, which is fine.)
            if command -v objdump >/dev/null 2>&1 && command -v nm >/dev/null 2>&1 && [ -f "$script_lib" ]; then
                if ! objdump -p "$script_lib" 2>/dev/null | grep -q "libae3d_native.dll"; then
                    own="$(nm -g "$script_lib" 2>/dev/null | grep -c ' T _\{0,1\}ae3d_' || true)"
                    if [ "${own:-0}" -ne 0 ]; then
                        fail "script $script_name (carries its own copy of $own engine calls)"
                        continue
                    fi
                fi
            fi
            ;;
        *)
            # Where there are no thunks, the sharper question: it defines none
            # of the engine's C itself.
            if command -v nm >/dev/null 2>&1 && [ -f "$script_lib" ]; then
                own="$(nm -g "$script_lib" 2>/dev/null | grep -c ' T _\{0,1\}ae3d_' || true)"
                if [ "${own:-0}" -ne 0 ]; then
                    fail "script $script_name (carries its own copy of $own engine calls)"
                    continue
                fi
            fi
            ;;
    esac
    pass "script $script_name"
done

if in_tier suites leaks platform; then
step "test suites"
SUITES="$(suite_sources)"
if [ "${AE3D_CI_GPU:-1}" = 0 ]; then
    drawn="$(AE3D_CI_GPU=1 suite_sources | wc -l)"
    drawn=$((drawn - $(printf '%s\n' $SUITES | wc -l)))
    [ "$drawn" -gt 0 ] && skip "$drawn suites that draw" "AE3D_CI_GPU=0: no window, GL context or Vulkan device here"
fi
build_together $SUITES
for suite in $SUITES; do
    name="$(basename "$suite" .ae)"
    if ! built_ok "$name"; then
        fail "$name (build)"
        sed 's/^/        /' "$BUILD_DIR/$name.log" | head -20
        continue
    fi
    if grep -qE "warning|^error" "$BUILD_DIR/$name.log"; then
        fail "$name (build warnings or errors)"
        grep -E "warning|^error" "$BUILD_DIR/$name.log" | sed 's/^/        /' | head -10
        continue
    fi
    needs_window=0
    grep -q "ae3d.engine" "$suite" && needs_window=1
    if [ "$needs_window" = 1 ] && ! have_display; then
        skip "$name" "no display"
        continue
    fi
    output="$(AE3D_FRAMES="$FRAMES" bounded "$RUN_LIMIT" ./build/"$name" 2>&1)"
    suite_status=$?
    if [ "$suite_status" -eq 124 ]; then
        fail "$name (still running after ${RUN_LIMIT}s)"
        printf '%s\n' "$output" | sed 's/^/        /' | tail -10
    elif [ "$suite_status" -ne 0 ]; then
        fail "$name$(died_on "$suite_status")"
        printf '%s\n' "$output" | sed 's/^/        /' | head -20
        trace_crash "$suite_status" ./build/"$name"
    elif printf '%s' "$output" | grep -q "all checks passed"; then
        pass "$name"
    elif printf '%s' "$output" | grep -q "SKIP" && ! printf '%s' "$output" | grep -q "FAIL"; then
        # A suite that cannot run where it finds itself, for want of a display,
        # a GPU or a driver, is not a suite that failed.
        skip "$name" "$(printf '%s' "$output" | grep -m1 "SKIP" | sed 's/.*SKIP *//')"
    else
        fail "$name"
        printf '%s\n' "$output" | sed 's/^/        /' | head -20
    fi
done

fi

if in_tier suites; then
step "Vulkan under the validation layer, synchronization included"
# The suites that read frames back, run again with the Khronos layer and its
# synchronization validation on: a frame copied out while the pass that wrote
# it was still writing, or overwritten while the copy was still reading it,
# or a draw through a descriptor naming a destroyed image, renders right on
# almost every device and run, and only the layer says so (#458). Any error
# the layer reports fails the suite. The loader names every layer it inserts
# when asked (VK_LOADER_DEBUG=layer): a run it did not insert the layer into
# would pass having checked nothing, so that is a skip, never a pass.
for name in test_fog test_overlay test_hud_layout test_damage test_backend_parity test_gi; do
    if ! built_ok "$name"; then
        skip "$name under the layer" "did not build"
        continue
    fi
    if ! have_display; then
        skip "$name under the layer" "no display"
        continue
    fi
    output="$(VK_LOADER_DEBUG=layer VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation \
              VK_LAYER_ENABLES=VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT \
              AE3D_FRAMES="$FRAMES" bounded "$RUN_LIMIT" ./build/"$name" 2>&1)"
    layered_status=$?
    if ! printf '%s' "$output" | grep -q 'Insert instance layer "VK_LAYER_KHRONOS_validation"'; then
        skip "$name under the layer" "the Khronos validation layer is not installed"
        continue
    fi
    errors="$(printf '%s\n' "$output" | grep -c 'Validation Error' || true)"
    if [ "$layered_status" -ne 0 ]; then
        fail "$name under the layer$(died_on "$layered_status")"
        printf '%s\n' "$output" | grep -v '^\[Vulkan Loader\]' | sed 's/^/        /' | tail -10
    elif [ "$errors" != 0 ]; then
        fail "$name under the layer ($errors validation errors)"
        printf '%s\n' "$output" | grep -o 'VUID-[A-Za-z0-9_-]*\|SYNC-HAZARD-[A-Z_-]*' | sort | uniq -c | sort -rn | head -5 | sed 's/^/        /'
    elif printf '%s' "$output" | grep -q "all checks passed"; then
        pass "$name under the layer"
    else
        skip "$name under the layer" "$(printf '%s' "$output" | grep -m1 "SKIP" | sed 's/.*SKIP *//')"
    fi
done

fi

if in_tier suites; then
step "the probes' light over the ray suites"
# The suites that put crowds, skinned figures and instance streams into the
# rays, again with the probes on (AE3D_GI=rt, #537): every instance's record
# is read by a probe's ray -- a crowd's pose frames, a posed figure's
# vertices -- where a wrong address loses the device. GI_AUTO keeps a
# software rasterizer on the sky's light, so nothing else here runs them.
for name in test_ray_shadows test_ray_occlusion; do
    if ! built_ok "$name"; then
        skip "$name with the probes" "did not build"
        continue
    fi
    if ! have_display; then
        skip "$name with the probes" "no display"
        continue
    fi
    output="$(AE3D_GI=rt AE3D_FRAMES="$FRAMES" bounded "$RUN_LIMIT" ./build/"$name" 2>&1)"
    probes_status=$?
    if [ "$probes_status" -ne 0 ]; then
        fail "$name with the probes$(died_on "$probes_status")"
        printf '%s\n' "$output" | sed 's/^/        /' | tail -10
    elif printf '%s' "$output" | grep -q "all checks passed"; then
        pass "$name with the probes"
    elif printf '%s' "$output" | grep -q "SKIP" && ! printf '%s' "$output" | grep -q "FAIL"; then
        skip "$name with the probes" "$(printf '%s' "$output" | grep -m1 "SKIP" | sed 's/.*SKIP *//')"
    else
        fail "$name with the probes"
        printf '%s\n' "$output" | sed 's/^/        /' | head -20
    fi
done

fi

if in_tier apps; then
step "examples build and run"
# The scenes' tools are built in the same pass when the scenes run:
# build_together starts from a clean status directory, so a later call would
# forget that the examples built.
scene_tools=""
if [ -n "$SCENES" ]; then
    scene_tools="tools/ae3d_bench.ae tools/measure_scene.ae tools/ae3d_agent.ae tools/ae3d_view.ae tools/critique_scene.ae tools/zombie_street.ae tools/bake_impostor.ae tools/fold_changes.ae tools/scene_parity.ae"
fi
build_together examples/*.ae $scene_tools
for example in examples/*.ae; do
    name="$(basename "$example" .ae)"
    if ! built_ok "$name"; then
        fail "$name (build)"
        sed 's/^/        /' "$BUILD_DIR/$name.log" | head -20
        continue
    fi
    if grep -qE "warning|^error" "$BUILD_DIR/$name.log"; then
        fail "$name (build warnings or errors)"
        grep -E "warning|^error" "$BUILD_DIR/$name.log" | sed 's/^/        /' | head -10
        continue
    fi
    if ! have_display; then
        skip "$name" "no display"
        continue
    fi
    AE3D_FRAMES="$EXAMPLE_FRAMES" bounded "$RUN_LIMIT" ./build/"$name" >/tmp/ae3d_run.log 2>&1
    example_status=$?
    if [ "$example_status" -eq 124 ]; then
        fail "$name (still running after ${RUN_LIMIT}s)"
        sed 's/^/        /' /tmp/ae3d_run.log | tail -10
    elif [ "$example_status" -eq 0 ]; then
        pass "$name"
    else
        fail "$name"
        sed 's/^/        /' /tmp/ae3d_run.log | head -20
    fi
done

fi

if [ -n "$SCENES" ] && in_tier apps; then
    . "$ROOT/scripts/ci_scenes.sh"
elif in_tier apps; then
    step "showcase scenes"
    skip "the street, the demo scene, the impostor atlas, renderer parity" "the local gate's; AE3D_CI_SCENES=1 runs them here"
fi

# The editor runs on either renderer, so both are checked: the Vulkan option
# used to report Vulkan and build an OpenGL renderer, which no OpenGL-only run
# could have caught.
# A number off the editor's report, or one no bound passes when the line is
# missing: a report without its play lines fails rather than reads as zero.
play_number() {   # play_number <key>
    play_value="$(sed -n "s/^$1 //p" "$report")"
    echo "${play_value:-999999999}"
}

check_editor_run() {
    editor_backend="$1"
    editor_scene="${2:-components}"
    name="ae3d_editor ($editor_backend)"
    if [ "$editor_scene" != "components" ]; then
        name="ae3d_editor ($editor_backend, $editor_scene)"
    fi
    report="$(mktemp)"
    snapshot="$(mktemp -t ae3d_shot.XXXXXX).png"
    log="$(mktemp)"
    # A bounded run ends itself; the timeout is only a backstop so a hang
    # fails the step rather than blocking it. Under Xvfb and llvmpipe a run
    # draws at one frame a second and is ready after 13 to 33 seconds, by
    # the runner: 90 seconds killed a run that was still drawing (#514).
    # Never onto the desktop. A run of this file opened an editor window per
    # backend per scene and took the keyboard with it, which makes it unusable
    # beside anything else. The window still exists and still answers the test
    # server; it is only never ordered to the front.
    # Every run plays too (#476): a host and two clients from the first
    # frame, each world drawn in turn, then measured and stopped before the
    # rest of the report is taken.
    # The profile names each stage and every frame, so a run the backstop
    # kills says where it stopped: its tail is printed with the failure.
    AETHER_UI_HEADLESS=1 \
    AE3D_EDITOR_PROFILE=1 \
    AE3D_EDITOR_BACKEND="$editor_backend" \
    AE3D_EDITOR_FRAMES=30 \
    AE3D_EDITOR_PLAY=2 \
    AE3D_EDITOR_SCENE="$editor_scene" \
    AE3D_EDITOR_SNAPSHOT="$snapshot" \
    AE3D_EDITOR_REPORT="$report" \
        timeout 180 ./build/ae3d_editor >"$log" 2>&1
    status=$?
    if grep -q 'no Vulkan driver' "$log"; then
        skip "$name" "$(sed -n 's/.*no Vulkan driver (\(.*\)),.*/\1/p' "$log" | head -1)"
        rm -f "$report" "$snapshot" "$log"
        return
    fi
    if [ "$status" -ne 0 ]; then
        fail "$name (exited $status)"
        tail -n 25 "$log" | sed 's/^/        /'
    elif [ ! -s "$report" ]; then
        fail "$name (wrote no report)"
    elif [ ! -s "$snapshot" ]; then
        fail "$name (wrote no viewport snapshot)"
    elif ! snapshot_is "$snapshot" "$(sed -n 's/^viewport //p' "$report")"; then
        # The snapshot is the frame the renderer produced, so its size is the
        # size the scene was rendered at. On the GPU path that is the
        # framebuffer's, in pixels; a snapshot that came back the canvas's size
        # in points is the viewport quietly rendering at half resolution on a
        # HiDPI screen, which looks like a slightly soft picture and nothing
        # else says a word.
        fail "$name (snapshot is $(snapshot_size "$snapshot"), the scene was rendered at $(sed -n 's/^viewport //p' "$report"))"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^backend //p' "$report")" != "$editor_backend" ]; then
        fail "$name (rendered with $(sed -n 's/^backend //p' "$report"))"
    elif ! grep -q '^frames 30$' "$report"; then
        fail "$name (did not reach 30 frames)"
        sed 's/^/        /' "$report"
    elif ! grep -qE '^models [0-9]+$' "$report" || \
         [ "$(sed -n 's/^models //p' "$report")" -lt 5 ]; then
        fail "$name (scene did not build)"
    elif [ "$(sed -n 's/^water //p' "$report")" != "1" ] || \
         [ "$(sed -n 's/^voxels //p' "$report")" != "1" ] || \
         [ "$(sed -n 's/^lights //p' "$report")" != "2" ] || \
         [ "$(sed -n 's/^scripted //p' "$report")" != "1" ] || \
         [ "$(sed -n 's/^bodies //p' "$report")" != "1" ] || \
         [ "$(sed -n 's/^figures //p' "$report")" != "2" ] ||          [ "$(sed -n 's/^motion_figures //p' "$report")" != "1" ]; then
        # The bodies count is the physics record on the cube: in the
        # roundtrip scene it has been through the file and back. The two
        # lights are a point and a spot, each standing for a light of its
        # own: every marker in a loaded scene used to stand for the same
        # one, so a scene of many lights came back lit by one.
        fail "$name (component types did not build)"
        sed 's/^/        /' "$report"
    elif [ "$editor_scene" = "roundtrip" ] && \
         [ "$(sed -n 's/^sky //p' "$report")" != "resources/sky/dusk.png" ]; then
        # The scene was given a sky from an image before it was saved. A dash
        # here is the file dropping it, which is what every program's scene
        # (five of the examples set a sky) lost on the way into the editor.
        fail "$name (the sky image did not survive the file: $(sed -n 's/^sky //p' "$report"))"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^motion_stuck //p' "$report")" != "0" ]; then
        # The humanoid on its muscles: it stands when the scene is simulated,
        # a blow to the chest knocks it down, and stopped, its bones are back
        # where they were.
        fail "$name (natural motion: $(sed -n 's/^motion_stuck //p' "$report") of stand, fall, put back failed)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^figure_stuck //p' "$report")" != "0" ]; then
        # The figure plays its clip while the scene is simulated: in the
        # roundtrip scene, the clip the file carried.
        fail "$name (the figure did not play while simulated)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^simulation_stuck //p' "$report")" != "0" ]; then
        # Simulate runs the scene's bodies in the editor's engine and, stopped,
        # puts every model back where it stood. The cube either did not fall
        # (the world never stepped under the editor) or did not come back.
        fail "$name (the simulation did not run, or did not put the scene back)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^viewport_path //p' "$report")" = "gpu-unbuilt" ]; then
        # The GPU path was taken and the renderer was never built on it, so the
        # viewport is a rectangle that never draws. Nothing else notices: the
        # report is written, the run ends, and every counter in it reads zero.
        fail "$name (the GPU viewport was chosen and never built)"
        sed 's/^/        /' "$report"
    elif [ "$(uname -s)" = "Darwin" ] && \
         [ "$(sed -n 's/^backend //p' "$report")" = "opengl" ] && \
         [ "$(sed -n 's/^viewport_path //p' "$report")" != "gpu" ]; then
        # Every Mac has a GL device, so a blit here is a silent fall back to
        # reading the framebuffer to the CPU every frame and rendering the
        # viewport at half resolution. Both look right in a snapshot.
        #
        # OpenGL only: Vulkan cannot draw into a GL context, so it keeps the
        # framebuffer of its own and the blit that shows it.
        fail "$name (fell back to the blit viewport: $(sed -n 's/^viewport_path //p' "$report"))"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^stuck_rows //p' "$report")" != "0" ]; then
        # A row that records an undo step and moves its own readout looks exactly
        # like a row that works. Nine of them did that and nothing else.
        fail "$name ($(sed -n 's/^stuck_rows //p' "$report") inspector row(s) change nothing)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^blind_fields //p' "$report")" != "0" ]; then
        # A number field that applies its value but never shows it is a row the
        # user cannot read, and stuck_rows cannot see it: that check drives the
        # property directly and never looks at the control.
        fail "$name ($(sed -n 's/^blind_fields //p' "$report") number field(s) do not show their value)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^mis_styled //p' "$report")" != "0" ]; then
        # A class the sheet never defines styles nothing at all, and the widget
        # renders in the toolkit's default: a button that looks like somebody
        # meant to leave it plain. Nothing in the widget tree says otherwise.
        fail "$name ($(sed -n 's/^mis_styled //p' "$report") styled widget(s) are not painted what the theme asks for)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^chip_wrong //p' "$report")" != "0" ]; then
        # The three colour sliders never show the colour they add up to, so the
        # chip beside them is the only place it appears. A chip that is never
        # painted looks exactly like one showing a dark material.
        fail "$name (the colour chip is not the material's colour)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^unreached_by_edit //p' "$report")" != "0" ]; then
        # An edit reaches everything selected, not just the row the inspector
        # happens to be showing. The property paths always wrote to the set;
        # nothing could put two things in it until the toolkit could report a
        # modifier, so nothing had ever checked the second one was written to.
        fail "$name (an edit did not reach every selected object)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^unundone_scripts //p' "$report")" != "0" ]; then
        # Attaching a behaviour that records nothing leaves the next undo to
        # step back through whatever came before it, the same fault the gizmo
        # drag had.
        fail "$name ($(sed -n 's/^unundone_scripts //p' "$report") behaviour(s) cannot be undone)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^first_fps //p' "$report")" -lt 1 ]; then
        # The first frame rate the bar ever shows. It opened on 0 and climbed
        # through 1 and 2, because nothing was written until an interval had
        # been measured and the running average started from nothing: the first
        # thing the editor told anyone was that it managed two frames a second.
        # The editor writes down what it showed first, because by the time a
        # driver can ask, the average has climbed to something plausible.
        #
        # Zero, and nothing above it. The first measured interval is genuinely
        # variable, because the first frames of a run do the work of first
        # frames: it reads anywhere from 5 to 28 here between runs of the same
        # scene, and a threshold above that measures the machine rather than
        # the editor. Zero is the defect itself and cannot be reached while the
        # bar waits for a measurement, so this fails on the regression and on
        # nothing else.
        fail "$name (the bar opened on $(sed -n 's/^first_fps //p' "$report") fps)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^shading_disagrees //p' "$report")" != "0" ]; then
        # The switches are a scene-wide control over per-model uniforms, so the
        # two drift apart in both directions: a model added after a switch was
        # flipped never got it, and a loaded scene brings settings the panel
        # knows nothing about.
        fail "$name ($(sed -n 's/^shading_disagrees //p' "$report") model setting(s) disagree with the shading panel)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^unreached_shading //p' "$report")" != "0" ]; then
        # A shading switch that sets a global and reaches no model looks
        # exactly like one that works: the only witness is a frame nobody
        # compares. Each is flipped and the model asked what it now carries.
        fail "$name ($(sed -n 's/^unreached_shading //p' "$report") shading switch(es) reach no model)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^silent_drags //p' "$report")" != "0" ]; then
        # Checked before the undo count, because it is the other explanation
        # for it: a drag that never reaches the model leaves the model where it
        # started, and the undo after it steps back through whatever came
        # before and moves it away. Reported apart so a failure names the gizmo
        # or the history rather than leaving the reader to guess (#198).
        fail "$name ($(sed -n 's/^silent_drags //p' "$report") gizmo drag(s) moved nothing)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^unundone_drags //p' "$report")" != "0" ]; then
        # A drag of the gizmo that records nothing leaves the next undo to step
        # back through whatever came before it and put that back instead.
        fail "$name ($(sed -n 's/^unundone_drags //p' "$report") gizmo drag(s) cannot be undone)"
        sed 's/^/        /' "$report"
    elif [ "$(sed -n 's/^idle_actions //p' "$report")" != "0" ]; then
        # Duplicate, delete, frame selection and the three scripts, each asked
        # for its effect: a button that dispatches to nothing looks exactly like
        # one that works when the only witness is a person watching.
        fail "$name ($(sed -n 's/^idle_actions //p' "$report") action(s) do nothing)"
        sed 's/^/        /' "$report"
    elif grep -q '^selected none$' "$report"; then
        fail "$name (nothing selected)"
        sed 's/^/        /' "$report"
    elif [ "$(play_number play_views)" != "3" ] || [ "$(play_number play_welcomed)" != "2" ]; then
        # Play as a host and two clients: each of the three worlds drawn
        # through the viewport in the bounded run's frames, and both clients
        # welcomed over the loopback's 60 ms and 2% loss.
        fail "$name (play: $(play_number play_views) of 3 worlds drawn, $(play_number play_welcomed) of 2 clients welcomed)"
        sed 's/^/        /' "$report"
    elif [ "$(play_number play_prediction_um)" -gt 10000 ] || \
         [ "$(play_number play_own_um)" -gt 1000 ] || \
         [ "$(play_number play_remote_um)" -gt 10000 ]; then
        # Every player walked and stood: what a client predicted is what the
        # host did, within a centimetre, as tests/test_players.ae holds it;
        # at rest its own player within a millimetre of the host's, and the
        # others it draws within a centimetre.
        fail "$name (play: players off the host's -- reconciled $(play_number play_prediction_um) um, own $(play_number play_own_um) um, others $(play_number play_remote_um) um)"
        sed 's/^/        /' "$report"
    elif [ "$(play_number play_focus)" != "1" ]; then
        # W held in client 2's view walks client 2's player, and no other.
        fail "$name (play: the keys did not walk the player in view, and only it)"
        sed 's/^/        /' "$report"
    elif [ "$(play_number play_leaked)" != "0" ] || [ "$(play_number play_restored)" != "1" ]; then
        # Stop lets every session, world, player and floor go -- the
        # renderer's models and the editor's engine's objects back to what
        # they were -- and puts every networked row where it stood.
        fail "$name (play: Stop left $(play_number play_leaked) behind, or the scene not put back)"
        sed 's/^/        /' "$report"
    else
        pass "$name"
        sed 's/^/        /' "$report"
    fi
    rm -f "$report" "$snapshot" "$log"
}

if in_tier apps; then
step "editor"
# A print left in from working something out ships silently: it goes to the
# editor's own console, where it looks like a message the editor meant to
# write, and nothing else in this file reads that console. One did ship, and
# was found in a screenshot taken for another reason.
if grep -n "DBG" editor/editor.ae >/tmp/ae3d_debug.log; then
    fail "ae3d_editor (debug prints)"
    sed 's/^/        /' /tmp/ae3d_debug.log | head -5
else
    pass "ae3d_editor (debug prints)"
fi

UI_ROOT="${AETHER_UI_ROOT:-$ROOT/../aether-ui}"
# GTK draws its window through GL, GLES first. Mesa's software GLES has no
# half-float vertex data, so GTK's GL renderer did not start on a runner and
# every frame of the editor's window was painted by cairo on the CPU: 600 to
# 850 ms a frame, the editor at one frame a second, and its step fourteen
# minutes of a Linux run (#516). llvmpipe's desktop GL has what the renderer
# needs; GTK 4.14 takes it when asked.
if [ "$(uname -s)" = "Linux" ]; then
    export GDK_DEBUG="${GDK_DEBUG:+$GDK_DEBUG,}gl-prefer-gl"
fi
# The viewport at half its size on a runner, the composite scaling it up, as
# every suite and example there draws at a quarter of theirs: what costs a
# software rasteriser is the pixels it shades, and the editor's frame at full
# size was 600 to 850 ms of shadows and scene (#518). The local gate draws it
# whole.
editor_scale_was="${AE3D_RENDER_SCALE:-}"
if [ "$TIER" != all ]; then export AE3D_RENDER_SCALE="${AE3D_RENDER_SCALE:-50}"; fi
if [ ! -f "$UI_ROOT/ui/module.ae" ]; then
    skip "ae3d_editor" "aether-ui not found at $UI_ROOT"
elif ! have_display; then
    skip "ae3d_editor" "no display"
else
    # From nothing, not from whatever build.sh left behind. The editor builds
    # the engine library itself when it is missing, and it did that with a
    # different set of libraries than build.sh did: every run here passed
    # because build.sh had already built the library, and building the editor
    # first in a clean checkout failed on zlib.
    rm -f build/libae3d_native.* build/libae3d_native
    if ! ./editor/build_editor.sh >/tmp/ae3d_build.log 2>&1; then
        fail "ae3d_editor (build)"
        sed 's/^/        /' /tmp/ae3d_build.log | head -20
    elif grep -qE "warning|^error" /tmp/ae3d_build.log; then
        # Every other build in this file is gated on warnings and this one was
        # not, so an unused variable in the largest Aether source in the repo
        # went through ci without a word.
        fail "ae3d_editor (build warnings or errors)"
        grep -E "warning|^error" /tmp/ae3d_build.log | sed 's/^/        /' | head -10
    else
        sed -n 's/^built: /        /p' /tmp/ae3d_build.log
        # The roundtrip scene is this one saved and loaded again before the
        # run starts, so its report describes what came BACK, held to every
        # check the scene as built is and the sky besides: a scene that drops
        # a component on the way through the file shows up as a count that
        # fell. A runner runs it alone on OpenGL, since it fails wherever the
        # scene as built would; the local gate runs both, which says which of
        # the two broke.
        editor_backends="opengl vulkan"
        [ "$TIER" = all ] || editor_backends="vulkan"
        for editor_backend in $editor_backends; do
            check_editor_run "$editor_backend"
        done
        check_editor_run opengl roundtrip

        # A name the editor shares with the toolkit it imports is bound
        # differently inside the ui.window block than outside it, silently, and
        # that is how the Undo button came to step the toolkit's empty stack.
        collide_log="$(mktemp)"
        if ! ./build.sh tools/check_ui_names.ae >"$collide_log" 2>&1; then
            fail "ae3d_editor (names, build)"
            sed 's/^/        /' "$collide_log" | head -12
        elif AETHER_UI_ROOT="$UI_ROOT" ./build/check_ui_names >"$collide_log" 2>&1; then
            pass "ae3d_editor (names)"
        else
            fail "ae3d_editor (names)"
            sed 's/^/        /' "$collide_log" | head -12
        fi
        rm -f "$collide_log"

        # Everything above reads the report the editor writes about itself, and
        # that report comes from calling the handlers directly. A button that
        # cannot be hit, a field whose callback is not wired, a row that does
        # not respond to a click: all of them pass. So this presses the real
        # widgets through aether-ui's driver and asks the tree what changed.
        if ! have_display; then
            skip "ae3d_editor (driver)" "no display"
        elif ! ./build.sh tools/drive_editor.ae >/tmp/ae3d_driver_build.log 2>&1; then
            fail "ae3d_editor (driver, build)"
            sed 's/^/        /' /tmp/ae3d_driver_build.log | head -12
        else
            # Both backends in the local gate. The report checks have always
            # run on each, but nothing had ever pressed a widget on the Vulkan
            # one, and the editor's controls reach the renderer through a
            # vtable that only a real click exercises. A runner drives the
            # default backend, Vulkan, alone: each drive is five minutes under
            # a software rasteriser (#511), and the bounded runs above still
            # hold both backends there.
            driver_backends="opengl vulkan"
            [ "$TIER" = all ] || driver_backends="vulkan"
            for driver_backend in $driver_backends; do
                driver_log="$(mktemp)"
                # A backstop, as the editor's own runs have: an editor that
                # stops answering fails this step with its log, rather than
                # holding the runner until the job's limit cancels it and
                # takes every result after it along.
                if timeout 900 ./build/drive_editor --backend "$driver_backend" \
                        --port 8797 >"$driver_log" 2>&1; then
                    pass "ae3d_editor (driver, $driver_backend)"
                else
                    fail "ae3d_editor (driver, $driver_backend)"
                    # The failing lines, not the first twenty. The driver runs
                    # more checks than that now, so the head of its log is all
                    # the ones that passed and a failure two thirds of the way
                    # down was reported as a wall of ok with no reason in it.
                    grep -E 'FAIL|Error|error:' "$driver_log" \
                        | sed 's/^/        /' | head -12
                    # And the driver's own last words, which say WHY when the
                    # run never got to a check: "never answered /widgets" and
                    # the editor's output behind it. The greps above matched
                    # only the toolkit's warnings (an "Error" in a GTK
                    # message) the first time the editor ran on Linux, and
                    # the reason -- no test server on that backend -- was in
                    # the line they skipped.
                    grep -E 'never answered|could not find|no editor at|driver:' "$driver_log" \
                        | sed 's/^/        /' | head -6
                    tail -3 "$driver_log" | sed 's/^/        /'
                    # On a runner the whole log is the only way to read what
                    # led up to a failure -- which checks passed before the
                    # stroke that sculpted nothing, what the editor printed
                    # between them -- since nothing else of the run survives.
                    # Bounded, and only here; a local run has the file.
                    if [ -n "${CI:-}" ]; then
                        echo "        --- the driver's log ---"
                        head -300 "$driver_log" | sed 's/^/        /'
                    fi
                fi
                rm -f "$driver_log"
            done
        fi
    fi
fi

if [ -n "$editor_scale_was" ]; then export AE3D_RENDER_SCALE="$editor_scale_was"; else unset AE3D_RENDER_SCALE; fi
fi

# On the suites' runner: the two Linux runners take about as long with it
# there, and the apps' one is the run's longest without it.
if in_tier suites; then
step "benchmarks"
# A shared runner is not a machine anyone should take a timing from, and a
# software rasteriser needs orders of magnitude longer per frame than the
# hardware these numbers describe. On CI the benchmarks run briefly, as smoke
# tests; AE3D_BENCH_FRAMES unset gives the counts the numbers were measured at.
if [ -n "${CI:-}" ]; then
    export AE3D_BENCH_FRAMES="${AE3D_BENCH_FRAMES:-10}"
    export AE3D_BENCH_BLOCKS="${AE3D_BENCH_BLOCKS:-1}"
fi
build_together benchmarks/bench_*.ae
for bench in benchmarks/bench_*.ae; do
    [ -e "$bench" ] || continue
    name="$(basename "$bench" .ae)"
    if ! built_ok "$name"; then
        fail "$name (build)"
        sed 's/^/        /' "$BUILD_DIR/$name.log" | head -20
        continue
    fi
    if grep -qE "warning|^error" "$BUILD_DIR/$name.log"; then
        fail "$name (build warnings or errors)"
        continue
    fi
    if output="$(AE3D_WIDTH= AE3D_HEIGHT= bounded "$RUN_LIMIT" ./build/"$name" 2>&1)"; then
        pass "$name"
        printf '%s\n' "$output" | sed 's/^/        /'
    else
        fail "$name"
        printf '%s\n' "$output" | sed 's/^/        /' | head -20
    fi
done

fi

# leaks stops the target and reads its heap, which needs a debugger attach that
# some sandboxes deny: the process ends up stopped and neither side moves again.
# AE3D_SKIP_LEAKS=1 is for those, and CI never sets it.
if [ -n "${AE3D_SKIP_LEAKS:-}" ]; then
    step "leak check, headless suites"
    skip "all" "AE3D_SKIP_LEAKS is set"
elif command -v leaks >/dev/null 2>&1 && in_tier leaks; then
    step "leak check, headless suites"
    # Run JOBS at a time, each into a file of its own, and judged in order
    # after: one at a time they were half of the macOS runner's minutes, and
    # what a leak run reports is the heap at exit, which a neighbour cannot
    # change.
    export leak_dir="$(mktemp -d)" RUN_LIMIT
    leak_one() {   # leak_one <name>
        MallocStackLogging=1 bounded "$RUN_LIMIT" leaks --atExit -- "./build/$1" >"$leak_dir/$1.out" 2>&1
    }
    export -f bounded
    leak_targets=""
    for suite in tests/test_*.ae benchmarks/bench_*.ae; do
        [ -e "$suite" ] || continue
        name="$(basename "$suite" .ae)"
        [ -x "build/$name" ] && leak_targets="$leak_targets $name"
    done
    in_pool leak_one $leak_targets
    for suite in tests/test_*.ae benchmarks/bench_*.ae; do
        [ -e "$suite" ] || continue
        name="$(basename "$suite" .ae)"
        [ -f "$leak_dir/$name.out" ] || continue
        # Only allocations this code lost count, judged by whose stack they are
        # on rather than by how leaks labelled them.
        #
        # A program that opens a window produces two kinds of noise it cannot do
        # anything about. NSXPCConnection retain cycles inside the window
        # server's machinery come back as ROOT CYCLE, which is easy to exclude.
        # But destroying the window also lets AppKit strand a stray NSArray
        # inside its own accessibility teardown, and that arrives as a ROOT
        # LEAK, intermittently. Counting ROOT LEAK lines would make this flaky.
        #
        # Asking whether the binary appears anywhere in the stack does not
        # separate them either: AppKit stranded that array under
        # glfwDestroyWindow, which main called, so main is in its stack too.
        # What tells them apart is how far the binary's frame is from the
        # allocation. Something this code lost was allocated a frame or two
        # below its own call; AppKit's stray has ten Apple frames in between.
        #
        # So a leak counts when a frame within four of the allocation is in
        # this binary. That is what lets the suites using ae3d.engine be
        # checked at all: they were skipped wholesale for opening a window, and
        # the exclusion was hiding a lost model in each of them.
        output="$(cat "$leak_dir/$name.out")"
        report="$(printf '%s' "$output" | grep -o '[0-9]* leaks for [0-9]* total leaked bytes' | tail -1)"
        lost="$(printf '%s' "$output" | awk -v bin="$name" '
            /^STACK OF /   { inblock = (index($0, "ROOT LEAK") > 0); ours = 0; next }
            inblock && $1 ~ /^[0-9]+$/ && $1 + 0 <= 4 && index($0, bin) { ours = 1 }
            inblock && /^====/ { if (ours) n++; inblock = 0 }
            END { print n + 0 }
        ')"
        cycles="$(printf '%s' "$output" | grep -c 'ROOT CYCLE')"
        if [ -z "$report" ]; then
            skip "$name" "no leak report"
        elif [ "$lost" -eq 0 ]; then
            if [ "$cycles" -gt 0 ]; then
                pass "$name (no lost allocations; $cycles system retain cycle(s) from the GPU context)"
            else
                pass "$name"
            fi
        else
            fail "$name ($report, $lost from this code)"
            printf '%s' "$output" | grep -A3 'ROOT LEAK' | sed 's/^/        /' | head -12
        fi
    done
    rm -rf "$leak_dir"
fi

printf '\n'
if [ "$failures" -eq 0 ]; then
    printf 'ci: everything passed'
    [ "$skipped" -gt 0 ] && printf ' (%d skipped)' "$skipped"
    printf '\n'
    exit 0
fi
printf 'ci: %d failure(s)\n' "$failures"
exit 1
