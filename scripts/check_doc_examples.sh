#!/usr/bin/env bash
# The motion docs' code is the examples' code (#1027).
#
# Every ```aether block in docs/motion/*.md follows a line
#
#     <!-- example: examples/docs/<program>.ae#<region> -->
#
# and is, line for line, the region of that program between its two
# `// [<region>]` lines, their common indentation taken off. ci.sh builds
# every program under examples/docs/, so a block that passes here is code
# that compiles; a block with no marker, or one that drifted from its
# program, fails.
#
#   scripts/check_doc_examples.sh          # 0 all agree, 1 a block does not, 2 cannot check
set -u
cd "$(dirname "$0")/.." || exit 2
[ -d docs/motion ] || { echo "no docs/motion"; exit 2; }

# The region `$2` of program `$1`, dedented.
region() {
    awk -v want="$2" '
        { line = $0; sub(/^[ \t]+/, "", line) }
        line == "// [" want "]" { inside++; next }
        inside == 1 { print }
    ' "$1" | awk '
        { lines[NR] = $0
          if ($0 ~ /[^ \t]/) { match($0, /^[ \t]*/); if (least == "" || RLENGTH < least) least = RLENGTH } }
        END { for (i = 1; i <= NR; i++) print substr(lines[i], (least == "" ? 0 : least) + 1) }
    '
}

failures=0
blocks=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for doc in docs/motion/*.md; do
    # Each block as <marker or "-">\t<line number>, then its lines into a file of its own.
    awk -v dir="$work" -v doc="$doc" '
        /^<!-- example: .* -->$/ { marker = $3; marker_line = NR; next }
        /^```aether$/ { n++; inside = 1; out = dir "/" n
                        printf "%s\t%d\t%s\n", (marker_line == NR - 1 ? marker : "-"), NR, out >> (dir "/index")
                        printf "" > out; next }
        /^```$/ && inside { inside = 0; close(out); next }
        inside { print >> out }
    ' "$doc"
    [ -f "$work/index" ] || continue
    while IFS="$(printf '\t')" read -r marker at file; do
        blocks=$((blocks + 1))
        if [ "$marker" = "-" ]; then
            echo "$doc:$at: a code block with no example marker before it"
            failures=$((failures + 1))
            continue
        fi
        program="${marker%%#*}"
        name="${marker#*#}"
        if [ ! -f "$program" ]; then
            echo "$doc:$at: $program is not there"
            failures=$((failures + 1))
            continue
        fi
        region "$program" "$name" >"$work/want"
        if [ ! -s "$work/want" ]; then
            echo "$doc:$at: $program has no region [$name]"
            failures=$((failures + 1))
        elif ! diff -u "$work/want" "$file" >"$work/diff"; then
            echo "$doc:$at: the block is not $program's [$name]"
            sed 's/^/    /' "$work/diff" | head -20
            failures=$((failures + 1))
        fi
    done <"$work/index"
    rm -f "$work"/*
done
if [ "$failures" -gt 0 ]; then
    echo "$failures of $blocks blocks do not match their programs"
    exit 1
fi
echo "$blocks blocks, each its program's"
exit 0
