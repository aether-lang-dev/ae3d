# The showcase scenes, as the gate holds them: the street played by sixteen
# and wandered, the demo scene measured through the channel, critiqued and
# held to its recorded cost, the impostor atlas rebaked, and the scenes drawn
# alike by both renderers. Sourced by ci.sh when it runs the scenes -- always
# on a developer's machine, on a runner only with AE3D_CI_SCENES=1 (#511) --
# after the examples and the tools below are built; it uses ci.sh's helpers
# (step, pass, fail, skip, built_ok, bounded, have_display) and its
# variables.

step "the street, played by sixteen"
# examples/net_street.ae's bounded run (#489): the zombie street with a host
# and fifteen bot clients over loopback UDP, every side's link 50 ms each way
# and 2% lost, ten seconds of play after they have all joined. What the
# multiplayer layer is held to at the scale #413 asked for: every client
# under 20 KB a second down and 4 up in every second of it, every client's
# horde the host's at every tick it reaches, every seal's hash the host's,
# the two cars two of the players drive with their fields the host's, and
# every client's own player where it predicted it. A number missing from
# the report fails rather than reads as zero.
#
# The play runs on a clock of its own, in fixed steps, as many a frame as
# the wall clock has gone: a software renderer drawing a frame in two
# seconds (llvmpipe on the Linux runner) plays the same ten seconds, and the
# same figures, as a GPU drawing a hundred and forty frames a second. When
# a frame was a step, the Linux runner's 22 frames were 22 steps of every
# session: the bots were made, and the ten seconds ran out before the host
# had welcomed one. Now the run is its twenty-odd seconds of play and
# startup there as here.
street_number() {   # street_number <key>
    street_value="$(sed -n "s/^net_street $1 //p" /tmp/ae3d_net_street.log)"
    echo "${street_value:-999999999}"
}
if built_ok net_street && have_display; then
    AE3D_FRAMES=1000000 AE3D_NET_SECONDS=10 bounded "$RUN_LIMIT" ./build/net_street >/tmp/ae3d_net_street.log 2>&1
    if ! grep -q "^net_street players" /tmp/ae3d_net_street.log && grep -q "could not create window\|failed to initialise\|no Vulkan driver" /tmp/ae3d_net_street.log; then
        skip "net_street (sixteen players)" "the scene could not open a window here"
    elif [ "$(street_number players)" != "16" ]; then
        fail "net_street (sixteen players: $(street_number players) played)"
        sed 's/^/        /' /tmp/ae3d_net_street.log | tail -12
    elif [ "$(street_number down_most_bps)" -ge 20480 ] || [ "$(street_number up_most_bps)" -ge 4096 ]; then
        fail "net_street (a client took $(street_number down_most_bps) bytes a second, or sent $(street_number up_most_bps))"
        sed 's/^/        /' /tmp/ae3d_net_street.log | tail -12
    elif [ "$(street_number checksums_compared)" -lt 100 ] || [ "$(street_number checksums_different)" != "0" ] || \
         [ "$(street_number seals_checked)" -lt 100 ] || [ "$(street_number seals_diverged)" != "0" ]; then
        fail "net_street (hordes: $(street_number checksums_different) of $(street_number checksums_compared) ticks off the host's, $(street_number seals_diverged) of $(street_number seals_checked) seals diverged)"
        sed 's/^/        /' /tmp/ae3d_net_street.log | tail -12
    elif [ "$(street_number car_fields_compared)" -lt 100 ] || [ "$(street_number car_fields_different)" != "0" ] ||          [ "$(street_number drivers_named)" != "15" ] || [ "$(street_number car_slowest_mmps)" -lt 3000 ]; then
        # Two of the players drive the cars: their speed and horn, fields of
        # the car's script state (#486), on every client as the host has
        # them at each snapshot's tick, bit for bit; their driver's name on
        # all fifteen; and both cars going round, 3 m/s on average at the
        # least, a turn and the pull away from it among the ten seconds.
        fail "net_street (the cars: fields off at $(street_number car_fields_different) of $(street_number car_fields_compared) snapshots, drivers named on $(street_number drivers_named) of 15 clients, the slowest car $(street_number car_slowest_mmps) mm/s)"
        sed 's/^/        /' /tmp/ae3d_net_street.log | tail -12
    elif [ "$(street_number prediction_worst_um)" != "0" ]; then
        # A client's player and the host's take the same steps from the
        # same state (#413): no reconciliation ever moves one.
        fail "net_street (a reconciliation moved a client's own player $(street_number prediction_worst_um) um)"
        sed 's/^/        /' /tmp/ae3d_net_street.log | tail -12
    else
        pass "net_street (sixteen players)"
        grep -E "^net_street:|^  the host's frame|^net_street " /tmp/ae3d_net_street.log | sed 's/^/        /'
    fi
else
    skip "net_street (sixteen players)" "no display or no build"
fi

step "a character wanders the street"
# The on-foot character walks, runs and jumps 10,000 random moves through
# street_drive's street, pushing the props it meets, and after every move is
# asked how deep it is into the street itself -- kerbs, steps, buildings --
# and whether it fell through. (Not into what moves: a walker that walks into
# it, on the runner's own clock, is the world moving, and the next move
# answers it.) Resting contact keeps up to the solver's 5 mm slop; past 6 mm, or
# under the street, is a bug (#420).
if built_ok street_drive && have_display; then
    AE3D_ON_FOOT=3 bounded "$RUN_LIMIT" ./build/street_drive >/tmp/ae3d_wander.log 2>&1
    wander_line="$(grep "street_drive: wandered" /tmp/ae3d_wander.log)"
    if [ -z "$wander_line" ] && grep -q "could not create window\|failed to initialise\| 0 steps, 0 frames" /tmp/ae3d_wander.log; then
        # A runner with a display but no GL or Vulkan it can open (the macOS
        # and Windows hosted ones) runs the examples to an empty window and
        # this to nothing.
        skip "street_drive wander" "the scene could not open a window here"
    elif [ -z "$wander_line" ]; then
        fail "street_drive wander (no report)"
        sed 's/^/        /' /tmp/ae3d_wander.log | tail -10
    elif echo "$wander_line" | grep -q " 0 over 6 mm; 0 falls through"; then
        pass "street_drive wander"
        echo "        $wander_line"
    else
        fail "street_drive wander"
        echo "        $wander_line"
    fi
else
    skip "street_drive wander" "no display or no build"
fi

step "the demo scene, measured through the channel"
# The scene the engine is demonstrated with, asked what it drew rather than
# looked at: what every model is made of, whether the image its material names
# was loaded, what colour each surface arrived at, whether a camera that has
# not moved draws the same frame twice, and whether seeking a clip moves the
# part it drives. Everything a screenshot would be read for, as numbers.
# tools/measure_scene.ae attaches to a scene this script starts, the way the
# frame budget does, on both renderers: the measurement is of the engine, and
# the engine is taken forward on Vulkan.
run_measure() {   # run_measure <backend> <port>
    measure_backend="$1"
    measure_port="$2"
    measure_name="zombie_street (measured, $measure_backend)"
    measure_log="$(mktemp)"
    measure_scene_log="$(mktemp)"
    AE3D_AGENT="$measure_port" ./build/zombie_street "$measure_backend" >"$measure_scene_log" 2>&1 &
    measure_scene=$!
    # The scene opens its port after the window and the first frame, so the
    # first question can arrive before there is anything to answer it. Retried
    # only while that is what came back, and only while the scene is alive.
    measured=1
    attempt=0
    while [ "$attempt" -lt 50 ]; do
        kill -0 "$measure_scene" 2>/dev/null || break
        bounded "$RUN_LIMIT" ./build/measure_scene "$measure_port" >"$measure_log" 2>&1
        measured=$?
        grep -q 'nothing answering' "$measure_log" || break
        attempt=$((attempt + 1))
        sleep 0.2
    done
    if ! kill -0 "$measure_scene" 2>/dev/null; then
        # The scene stopped without complaining, which is the engine saying it
        # has nowhere to draw. A runner with a display is where this is asked.
        if grep -q 'no Vulkan driver' "$measure_scene_log"; then
            skip "$measure_name" "no Vulkan driver"
        else
            skip "$measure_name" "the scene could not open a window"
        fi
    elif [ "$measured" -eq 0 ]; then
        pass "$measure_name"
        # The first line carries what the scene costs, which is the number this
        # scene exists to report and is worth having in the log of every run.
        head -1 "$measure_log" | sed 's/^/        /'
    else
        fail "$measure_name"
        grep -E 'FAIL|error:|measure_scene:' "$measure_log" | sed 's/^/        /' | head -12
    fi
    kill "$measure_scene" 2>/dev/null
    wait "$measure_scene" 2>/dev/null
    rm -f "$measure_log" "$measure_scene_log"
}
if ! built_ok ae3d_view; then
    fail "ae3d_view (build)"
else
    pass "ae3d_view (build)"
fi
if ! built_ok measure_scene; then
    fail "measure_scene (build)"
elif ! have_display; then
    skip "zombie_street (measured)" "no display"
elif ! built_ok zombie_street; then
    skip "zombie_street (measured)" "it did not build"
else
    run_measure opengl 7913
    run_measure vulkan 7914
fi

step "the impostor atlas rebakes"
# The crowd's far tier draws from atlases baked out of the figure by
# tools/bake_impostor: the figure seen from eight angles by eight frames of
# its walk, its albedo and its normals. The atlases are committed beside the
# export; this bakes them again to a scratch path and holds the bake to what
# it has to produce -- every cell with a figure in it -- so the tool and the
# capture channel it reads through stay working on every runner with a
# display.
if ! built_ok bake_impostor; then
    fail "bake_impostor (build)"
    sed 's/^/        /' "$BUILD_DIR/bake_impostor.log" | head -20
elif ! have_display; then
    skip "bake_impostor" "no display"
else
    bake_out="$(mktemp -d)"
    bounded "$RUN_LIMIT" ./build/bake_impostor resources/blender/zombie_street/manifest.json Zombie_Body "$bake_out/impostor.png" >/tmp/ae3d_bake.log 2>&1
    bake_status=$?
    if grep -q "no window" /tmp/ae3d_bake.log; then
        skip "bake_impostor" "the bake could not open a window"
    elif [ "$bake_status" -eq 0 ] && grep -q ", 0 empty cells" /tmp/ae3d_bake.log        && [ -s "$bake_out/impostor.png" ] && [ -s "$bake_out/impostor_normal.png" ] && [ -s "$bake_out/impostor.json" ]; then
        pass "bake_impostor"
        grep "bake_impostor: wrote" /tmp/ae3d_bake.log | sed 's/^/      /'
    else
        fail "bake_impostor"
        sed 's/^/        /' /tmp/ae3d_bake.log | tail -30
    fi
    rm -rf "$bake_out"
fi

step "the demo scene, held to what a scene has to look like"
# Texel density, relief, proportion and whether a planted foot stays planted.
# Every one of them is a property of the scene the engine already holds, and
# none of them was ever asked for -- which is how the street came to be a row of
# boxes at ninety texels to the metre with every measurement passing.
# Both renderers. The whole point is that the scene is judged by the numbers the
# channel answers with, on the backend it is taken forward on -- so the critique
# reads the Vulkan frame too, and its verdict on the lighting is proven there.
# Where a backend cannot give the frame back (software Vulkan on a headless
# runner has no swapchain to read), it skips rather than fails.
run_critique() {   # run_critique <backend> <port>
    crit_backend="$1"
    crit_port="$2"
    crit_name="zombie_street (critique, $crit_backend)"
    crit_arg=""
    # The Vulkan pass proves the lighting and the frame-reading on the target;
    # its animation sampling is the same pose the OpenGL pass already judges and
    # would run for minutes on the software renderer a headless runner uses, so
    # it is skipped there.
    [ "$crit_backend" = vulkan ] && crit_arg="--frame-only"
    crit_log="$(mktemp)"
    crit_scene_log="$(mktemp)"
    AE3D_AGENT="$crit_port" AE3D_FRAMES=100000 ./build/zombie_street "$crit_backend" >"$crit_scene_log" 2>&1 &
    crit_scene=$!
    # The scene opens its port after the window and the first frame; asked
    # again while that is what came back and the scene is alive.
    crit_status=2
    attempt=0
    while [ "$attempt" -lt 50 ]; do
        kill -0 "$crit_scene" 2>/dev/null || break
        bounded "$RUN_LIMIT" ./build/critique_scene "$crit_port" $crit_arg >"$crit_log" 2>&1
        crit_status=$?
        grep -q 'nothing answering' "$crit_log" || break
        attempt=$((attempt + 1))
        sleep 0.2
    done
    if ! kill -0 "$crit_scene" 2>/dev/null && [ "$crit_status" -ne 0 ]; then
        # A backend the machine has no driver for is a skip, not a failure:
        # there is nothing to judge, and the scene said so on its way out.
        if grep -q 'no Vulkan driver' "$crit_scene_log"; then
            skip "$crit_name" "no Vulkan driver on this machine"
        else
            skip "$crit_name" "the scene could not open a window"
        fi
    elif [ "$crit_status" -eq 0 ]; then
        pass "$crit_name"
        grep -E '^  (ok|FAIL|note)' "$crit_log" | sed 's/^/      /' | head -30
    elif [ "$crit_status" -eq 3 ]; then
        skip "$crit_name" "$(grep -m1 'SKIP' "$crit_log" | sed 's/.*SKIP *//' || echo 'the frame could not be read')"
    else
        fail "$crit_name"
        grep -E 'FAIL|error:|critique_scene:' "$crit_log" | sed 's/^/        /' | head -16
    fi
    kill "$crit_scene" 2>/dev/null
    wait "$crit_scene" 2>/dev/null
    rm -f "$crit_log" "$crit_scene_log"
}
if ! built_ok critique_scene; then
    fail "critique_scene (build)"
elif ! have_display; then
    skip "zombie_street (critique)" "no display"
elif ! built_ok zombie_street; then
    skip "zombie_street (critique)" "it did not build"
else
    run_critique opengl 7914
    run_critique vulkan 7926
fi

step "the demo scene, held to what it cost last time"
# The benchmark. Written in ae3d against ae3d's own protocol rather than in
# another language against a second copy of it, which is the point of the
# channel having a client in the engine's own language.
#
# Draw calls, triangles and state changes are the same on every machine that
# runs this, so they are compared against the recorded figures exactly and a
# single extra program bind fails the build. The milliseconds beside them are
# compared only when the card that recorded them is the card running them, and
# reported otherwise: a time from one GPU says nothing about another.
#
# Both renderers, because a cost that can only be measured on one of them is
# a cost that regresses unseen on the other; Vulkan skips where there is no
# driver, the way every other Vulkan check here does.
frame_cost() {   # frame_cost <backend> <port>
    cost_backend="$1"
    cost_port="$2"
    cost_name="zombie_street (frame cost, $cost_backend)"
    cost_arg="opengl"
    [ "$cost_backend" = vulkan ] && cost_arg="vulkan"
    cost_log="$(mktemp)"
    scene_log="$(mktemp)"
    AE3D_AGENT="$cost_port" ./build/zombie_street $cost_arg >"$scene_log" 2>&1 &
    cost_scene=$!
    # The scene opens its port after the window and the first frame, so the
    # first question can arrive before there is anything to answer it. Retried
    # only while that is what came back, and only while the scene is alive.
    costed=1
    attempt=0
    while [ "$attempt" -lt 50 ]; do
        kill -0 "$cost_scene" 2>/dev/null || break
        bounded "$RUN_LIMIT" ./build/ae3d_bench "$cost_port" >"$cost_log" 2>&1
        costed=$?
        grep -q 'nothing answering' "$cost_log" || break
        attempt=$((attempt + 1))
        sleep 0.2
    done
    if ! kill -0 "$cost_scene" 2>/dev/null; then
        if grep -q 'no Vulkan driver' "$scene_log"; then
            skip "$cost_name" "no Vulkan driver"
        else
            skip "$cost_name" "the scene could not open a window"
        fi
    elif [ "$costed" -eq 0 ]; then
        pass "$cost_name"
        sed 's/^/        /' "$cost_log" | head -20
    else
        fail "$cost_name"
        sed 's/^/        /' "$cost_log" | head -20
    fi
    kill "$cost_scene" 2>/dev/null
    wait "$cost_scene" 2>/dev/null
    rm -f "$cost_log" "$scene_log"
}
if ! built_ok ae3d_bench; then
    fail "ae3d_bench (build)"
    sed 's/^/        /' "$BUILD_DIR/ae3d_bench.log" | head -20
elif ! have_display; then
    skip "zombie_street (frame cost)" "no display"
elif ! built_ok zombie_street; then
    skip "zombie_street (frame cost)" "it did not build"
else
    frame_cost opengl 7915
    frame_cost vulkan 7916
fi

# The horde at 20,000, held to its own budget (#498): zombie_city at a fixed
# tick, held at frame 90 so the crowd stands where it stood when the budget
# was recorded, its draw calls, triangles and binds compared exactly and its
# passes' times on the card that recorded them. Twice: the default near band,
# and the 28 m one, where the shadow stage once took 9.6 ms of a 7.6 fps
# frame. On Vulkan, the renderer the engine is taken forward on.
city_cost() {   # city_cost <name> <port> <baseline> [VAR=value ...]
    city_name="zombie_city at 20,000 ($1, vulkan)"
    city_port="$2"
    city_baseline="$3"
    shift 3
    city_log="$(mktemp)"
    city_scene_log="$(mktemp)"
    env "$@" AE3D_API=vulkan AE3D_CROWD=20000 AE3D_TICK=60 AE3D_HOLD=90 AE3D_FRAMES=100000 \
        AE3D_AGENT="$city_port" ./build/zombie_city >"$city_scene_log" 2>&1 &
    city_scene=$!
    # The bench waits for the hold itself (--hold): before it, the crowd is
    # still walking to where the budget was recorded. Asked again while the
    # scene has not opened its port and is alive.
    costed=1
    attempt=0
    while [ "$attempt" -lt 300 ]; do
        kill -0 "$city_scene" 2>/dev/null || break
        bounded "$RUN_LIMIT" ./build/ae3d_bench "$city_port" --hold 90 --baseline "$city_baseline" >"$city_log" 2>&1
        costed=$?
        grep -q 'nothing answering' "$city_log" || break
        attempt=$((attempt + 1))
        sleep 0.2
    done
    if ! kill -0 "$city_scene" 2>/dev/null; then
        if grep -q 'no Vulkan driver' "$city_scene_log"; then
            skip "$city_name" "no Vulkan driver"
        else
            skip "$city_name" "the scene could not open a window"
        fi
    elif [ "$costed" -eq 0 ]; then
        pass "$city_name"
        sed 's/^/        /' "$city_log" | head -20
    else
        fail "$city_name"
        sed 's/^/        /' "$city_log" | head -20
    fi
    kill "$city_scene" 2>/dev/null
    wait "$city_scene" 2>/dev/null
    rm -f "$city_log" "$city_scene_log"
}
if ! built_ok ae3d_bench || ! built_ok zombie_city; then
    skip "zombie_city at 20,000 (frame cost)" "it did not build"
elif ! have_display; then
    skip "zombie_city at 20,000 (frame cost)" "no display"
elif [ -n "${CI:-}" ]; then
    skip "zombie_city at 20,000 (frame cost)" "20,000 figures on a software rasteriser is minutes a frame; a GPU's"
else
    city_cost "near band 12 m" 7917 resources/zombie_city.vulkan.budget.json
    city_cost "near band 28 m" 7918 resources/zombie_city_near28.vulkan.budget.json AE3D_NEAR=28
fi

step "the scenes, drawn alike by both renderers"
# The backend parity suite holds the renderers to each other on test scenes
# of a few models; this holds them to each other on the scenes a person looks
# at (#494), which is where zombie_city drew garbage on OpenGL at 3397101 with
# every suite passing. Each scene runs on both at a fixed tick and holds at
# the same frame, so the horde, the car and the clouds stand in the same
# place; tools/scene_parity.ae compares the two frames region by region
# (sky, facades, road, figures, the rest) against the tolerances it writes
# down, and fails on a hole: a model on one renderer where the other shows
# the sky or the clear colour.
# What the two do not both do is off here, by name: the ray-traced shadows
# and occlusion (Vulkan's alone; AE3D_RAYS=0), the eye's adaptation (it
# meters each renderer's own frame; AE3D_EYE=0) and the temporal pass (it
# folds in however many frames the hold drew; AE3D_TAA=0); the tool turns
# the screen-space reflections off (Vulkan's alone until #491).
#
# On a shared runner (CI set) both renderers are software rasterisers
# (llvmpipe and lavapipe on Linux), billed for every vertex and pixel, and
# the step has the few minutes the job has left. There it is the same check
# made lighter, each part for its reason:
# - 320 by 180, the size every other CI draw is made at: a quarter of the
#   pixels, and the grid's cells ten pixels across instead of twenty;
# - held at frame 12 rather than 90: every frame before the hold is drawn,
#   and any moment both renderers hold at is a moment to compare them at;
# - the city's horde a hundred strong with a 12 m near band (AE3D_CROWD=100
#   AE3D_NEAR=12): its 400 zombies drawn whole to 600 m are 12 million
#   triangles a frame, 19 s a frame on llvmpipe even at 320 by 180 and past
#   the step's limit before frame 12, and every lamp's face draws the horde
#   again for its shadow; a hundred at 12 m still stand in all three tiers
#   -- the near meshes, the far mesh, the impostors -- and a view takes
#   about a minute on both renderers (53 to 68 s on Mesa, 24 threads)
#   where 400 took over two;
# - four of its seven views, one for each region at its largest: 0, the
#   street with the horde in all three tiers; 2, low in the horde, the near
#   band's figures up close; 4, grazing along the wet road, where its
#   normal maps and the lamps' streaks are; 5, toward the moon, the sky, the
#   clouds and the skyline. Views 1, 3 and 6 are the same surfaces from
#   other places and stay in the full run on a GPU.
# The tolerances are the device's: a GPU is held to 1, two and a half
# times the worst it measured, and a software rasteriser to 2, its worst
# and half again (tools/scene_parity.ae; #503).
if [ -n "${CI:-}" ]; then
    parity_width=320
    parity_height=180
    parity_hold=12
    parity_views="0 2 4 5"
    parity_city="AE3D_CROWD=100 AE3D_NEAR=12"
else
    parity_width=640
    parity_height=360
    parity_hold=90
    parity_views="0 1 2 3 4 5 6"
    parity_city=""
fi
scene_parity() {   # scene_parity <program> <name> <port> [VAR=value ...]
    parity_program="$1"
    parity_view="$2"
    parity_name="scene parity ($2)"
    parity_port="$3"
    shift 3
    parity_log="$(mktemp)"
    parity_gl_log="$(mktemp)"
    parity_vk_log="$(mktemp)"
    # zombie_street takes its renderer as its argument; the examples, from
    # AE3D_API.
    parity_gl_arg=""
    parity_vk_arg=""
    if [ "$parity_program" = zombie_street ]; then
        parity_gl_arg="opengl"
        parity_vk_arg="vulkan"
    fi
    env "$@" AE3D_API=opengl AE3D_AGENT="$parity_port" AE3D_TICK=60 AE3D_HOLD="$parity_hold" \
        AE3D_RAYS=0 AE3D_EYE=0 AE3D_TAA=0 AE3D_HIDDEN=1 AE3D_WIDTH="$parity_width" AE3D_HEIGHT="$parity_height" \
        AE3D_FRAMES=100000 ./build/"$parity_program" $parity_gl_arg >"$parity_gl_log" 2>&1 &
    parity_gl=$!
    env "$@" AE3D_API=vulkan AE3D_AGENT="$((parity_port + 1))" AE3D_TICK=60 AE3D_HOLD="$parity_hold" \
        AE3D_RAYS=0 AE3D_EYE=0 AE3D_TAA=0 AE3D_HIDDEN=1 AE3D_WIDTH="$parity_width" AE3D_HEIGHT="$parity_height" \
        AE3D_FRAMES=100000 ./build/"$parity_program" $parity_vk_arg >"$parity_vk_log" 2>&1 &
    parity_vk=$!
    # Each scene opens its port after its window and its first frame; asked
    # again while that is what came back and both scenes are alive.
    parity_status=2
    attempt=0
    while [ "$attempt" -lt 300 ]; do
        kill -0 "$parity_gl" 2>/dev/null || break
        kill -0 "$parity_vk" 2>/dev/null || break
        bounded "$RUN_LIMIT" ./build/scene_parity "$parity_port" "$((parity_port + 1))" --hold "$parity_hold" --name "$parity_view" >"$parity_log" 2>&1
        parity_status=$?
        grep -q 'nothing answering' "$parity_log" || break
        attempt=$((attempt + 1))
        sleep 0.2
    done
    if [ "$parity_status" -eq 0 ]; then
        pass "$parity_name"
        grep -E '^scene_parity: .* against |^  (ok|--)' "$parity_log" | sed 's/^/      /'
    elif [ "$parity_status" -eq 124 ]; then
        fail "$parity_name (not held and compared within ${RUN_LIMIT}s)"
        tail -3 "$parity_gl_log" "$parity_vk_log" | sed 's/^/        /'
    elif [ "$parity_status" -eq 3 ]; then
        skip "$parity_name" "a frame cannot be read back on this machine"
    elif grep -q 'no Vulkan driver' "$parity_vk_log"; then
        skip "$parity_name" "no Vulkan driver"
    elif [ "$parity_status" -eq 2 ] && { ! kill -0 "$parity_gl" 2>/dev/null || ! kill -0 "$parity_vk" 2>/dev/null; }; then
        skip "$parity_name" "a scene could not open a window"
    else
        fail "$parity_name"
        grep -E '^  |scene_parity:' "$parity_log" | sed 's/^/        /' | head -24
        # Which scene went away, and its last words, before the logs go:
        # "the connection closed while reading" says one of them stopped
        # answering, not which, nor why (#547).
        for parity_side in opengl vulkan; do
            if [ "$parity_side" = opengl ]; then parity_pid="$parity_gl"; parity_side_log="$parity_gl_log"; else parity_pid="$parity_vk"; parity_side_log="$parity_vk_log"; fi
            if kill -0 "$parity_pid" 2>/dev/null; then
                echo "        $parity_side: still running; its last lines:"
            else
                wait "$parity_pid" 2>/dev/null
                echo "        $parity_side: exited with status $?; its last lines:"
            fi
            tail -6 "$parity_side_log" | sed 's/^/          /'
        done
    fi
    kill "$parity_gl" "$parity_vk" 2>/dev/null
    wait "$parity_gl" 2>/dev/null
    wait "$parity_vk" 2>/dev/null
    rm -f "$parity_log" "$parity_gl_log" "$parity_vk_log"
}
if ! built_ok scene_parity; then
    fail "scene_parity (build)"
    sed 's/^/        /' "$BUILD_DIR/scene_parity.log" | head -20
elif ! have_display; then
    skip "scene parity" "no display"
else
    parity_started="$(date +%s)"
    if built_ok zombie_street; then
        scene_parity zombie_street "zombie_street" 7941
    else
        skip "scene parity (zombie_street)" "it did not build"
    fi
    if built_ok zombie_city; then
        for parity_view in $parity_views; do
            scene_parity zombie_city "zombie_city, view $parity_view" 7941 AE3D_VIEW="$parity_view" $parity_city
        done
    else
        skip "scene parity (zombie_city)" "it did not build"
    fi
    if built_ok street_drive; then
        scene_parity street_drive "street_drive" 7941
    else
        skip "scene parity (street_drive)" "it did not build"
    fi
    echo "        the scenes compared in $(( $(date +%s) - parity_started ))s, ${parity_width} by ${parity_height} at frame ${parity_hold}"
fi
