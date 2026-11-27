#!/usr/bin/env bash
# Compile one Aether script into a shared library the editor can attach.
#
#   scripts/build_script.sh resources/scripts/spin.ae [build/scripts]
#
# A script is an ordinary source file with start and update in it, Unity's
# phases by Unity's names. It is compiled the same way anything else is and then linked as a shared
# library whose undefined symbols are resolved out of the host at load time:
# the runtime, and whatever native calls the engine code it imported makes.
#
# Build a script with the same tree that will run it. A script carries its
# own copy of what it imported, so the host and the script agree about what
# a Model is only while both were built from the same sources; the library
# says the layout it was built against and the loader refuses another
# (ae3d.script, component.script_layout).
#
# The paths are the caller's: a game with ae3d at ext/ae3d builds its own
# scripts with ext/ae3d/scripts/build_script.sh scripts/spinner.ae, from its
# own root.

set -euo pipefail

CALLER="$(pwd)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
absolute() { case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$CALLER/$1" ;; esac; }
SOURCE="$(absolute "${1:?usage: build_script.sh <script.ae> [output directory]}")"
OUT_DIR="$(absolute "${2:-build/scripts}")"
cd "$ROOT"

. "$ROOT/scripts/platform.sh"
. "$ROOT/scripts/native.sh"

NAME="$(basename "$SOURCE" .ae)"

mkdir -p "$OUT_DIR"

SUFFIX="$(ae3d_native_suffix)"

GEN="$OUT_DIR/$NAME.c"
LIB="$OUT_DIR/$NAME$SUFFIX"

CC="${CC:-cc}"
# The flags of the compiler this build uses, as ../build.sh asks for them
# (`--cc`, Aether 0.940 on; an older ae is asked as before).
ae_cflags() {
    ae cflags "$@" --cc "$CC" 2>/dev/null || ae cflags "$@" 2>/dev/null || true
}
AETHER_CFLAGS="$(ae_cflags --cflags)"
if [ -z "$AETHER_CFLAGS" ]; then
    echo "ae3d: 'ae cflags' produced nothing; is the toolchain on PATH?" >&2
    exit 1
fi

AETHER_LIB_DIR="$ROOT/src" aetherc "$SOURCE" "$GEN"

# Where the engine's library is, from the script's directory (its rpath).
NATIVE_DIR=".."
if [ "$(cd "$OUT_DIR" && pwd)" != "$ROOT/build/scripts" ]; then NATIVE_DIR="$ROOT/build"; fi

# What the script leaves to the program that loads it, by platform. A
# script uses the Aether runtime as any Aether code does -- its fields are
# named strings, its state is allocated -- and where that runtime comes
# from differs:
#   Linux    left undefined, and resolved against the host's at load: the
#            editor exports its symbols (-rdynamic), so the script shares
#            the host's runtime, its observers included.
#   macOS    the same, said to the linker: undefined names are looked up in
#            the loading program (-undefined dynamic_lookup).
#   Windows  a DLL resolves every name at its own link and an executable
#            exports nothing, so the script carries the runtime's library
#            itself. It shares the host's C runtime (UCRT), so memory one
#            allocates the other frees; what it does not share is the
#            runtime's own tables, so a store the script makes on an
#            @observable state is told to its own observers, not the
#            host's. aether-lang-dev/aether#2297 asks for the runtime and
#            the engine as one library both link.
RUNTIME_LIBS=""
case "$(uname -s)" in
    Darwin) LINK_FLAGS="-dynamiclib -undefined dynamic_lookup" ;;
    MINGW*|MSYS*|CYGWIN*)
        LINK_FLAGS="-shared"
        RUNTIME_LIBS="$(ae3d_runtime_link_flags "$(ae_cflags --libs)")" ;;
    *)      LINK_FLAGS="-shared" ;;
esac

if [ ! -f "$(ae3d_native_library)" ] || { [ -n "$RUNTIME_LIBS" ] && [ ! -f "$(ae3d_runtime_library)" ]; }; then
    ./build.sh --natives >/dev/null
fi

# A script in this tree's build/scripts is one directory below the library,
# which it finds there; one built elsewhere (a game's own build/scripts) finds
# it in this tree's build, by its whole path. It names
# GLFW as a program does: the engine's Aether it imports calls GLFW
# (ae3d.platform), and on Windows a DLL resolves everything at its link.
ae3d_glfw_flags
# A C name of its own (@c_callback) is written weak, and GNU ld's DLL leaves
# weak definitions out of what it exports -- by name in a .def too ("symbol
# wrong type"): every script on Windows was refused for not saying its
# layout (script_layout_hash). A script is one C file, each such name in it
# once, so there they are ordinary definitions, exported with the rest.
SCRIPT_DEFINES=""
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) SCRIPT_DEFINES="-DAETHER_WEAK_DEF=" ;;
esac
# shellcheck disable=SC2086
$CC -O2 -fwrapv $(ae3d_fp_flags) $(ae3d_native_pic_flag) $AETHER_CFLAGS $SCRIPT_DEFINES $(ae3d_program_includes "$GEN") $LINK_FLAGS \
    "$GEN" $(ae3d_native_link_flags "$NATIVE_DIR") $GLFW_LIBS $RUNTIME_LIBS -o "$LIB"

echo "built: $LIB"
