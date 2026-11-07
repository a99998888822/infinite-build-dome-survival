# Hammer / plasma dense-contact CPU optimization

Reproduction: `scenes/tests/hammer_plasma_performance.tscn`, headless Godot
4.7.1, 300 stationary high-HP grubs, level 5 weapon, multishot + water +
electric spark, three volleys, 180 manually stepped 60 Hz simulation frames.
This is simulation CPU timing, not an in-game GPU FPS measurement.

| Weapon | Before mean / p95 (ms) | After mean / p95 (ms) | Total damage before / after |
| --- | --- | --- | --- |
| Earth hammer | 6.78 / 44.72 | 5.96 / 40.58 | 168973 / 168973 |
| Plasma cannon | 23.98 / 152.47 | 11.33 / 60.93 | 44847 / 44847 |

The principal cost was repeated exact convex collision work for water and
ground lightning. Spells now share bounded immutable ellipse geometry, use
rectangle broad-phase queries, and reuse exact geometry results keyed by both
shapes and transforms. Shape changes invalidate results; live health, collider
enabled state and collision layer are checked before reuse. Cache entries are
bounded to 4096. Hammer skips already-hit targets before wall/head queries.
Damage events, effect count, timing, status reactions and artwork are retained.

Validation:

- Headless editor import passed.
- Continuous contact: 3337 checks, no failures, including transformed colliders,
  shape mutation, collider replacement and swept motion.
- Pixel combat effects: 27 checks, no failures.
- Ground lightning arc: 286 checks, no failures.
- Dense benchmark damage assertions passed for both weapons.
- Existing plasma contact (23), weapon trio (17), weapon contact regression (6)
  and enchantment order (6) failures were reproduced with the original code;
  their failure labels were identical before and after this change.

Remaining limitation: dense hit peaks still exceed a 16.7 ms CPU frame budget.
This change reduces the bottleneck but does not establish stable 60 FPS in
live gameplay. GPU frame time and moving-enemy combat need a separate measured
pass before claiming the overall performance issue resolved.

## Second pass: scheduler and warning updates

The scheduler now indexes tasks by ID and owner. Expired tasks are compacted in
one pass instead of searching and shifting the order array on every release.
Cancellation from a callback and immediate slot reuse retain insertion order;
new callbacks still wait until the next scheduler tick. Warning ground shaders
upload only uniforms that changed; the warning particle fade is likewise
updated only when it changes. Artwork, strike delay and damage are unchanged.

Measured isolated workload, including scheduling 5000 callbacks: 34.12 ms
before, 25.74 ms after. Cancelling 1000 distinct owners after that peak:
194.61 ms before, 3.26 ms after. Both paths executed all expected callbacks and
cleaned up all tasks. This addresses spikes during effect cleanup, rather than
claiming an equivalent percentage improvement for the entire game.

Final headless dense benchmark: hammer mean 5.79 ms, plasma mean 10.80 ms;
damage remains 168973 / 44847. Whole-battle mean improvement was not stable
enough to attribute an additional FPS gain to this pass. An alternating effect
parameter cache was measured and removed because it did not help consistently.

The benchmark now supports `--moving` and GPU rendering only with
`--background-capture`. The background helper verified private engine desktops
and `foreground_samples=0`. Moving rendered runs still show substantial contact
peaks (final plasma frame mean 29.05 ms / p95 130.44 ms). GPU-run wall times and
damage totals vary because engine physics/visual processing also runs between
manual steps; these are smoke/stress observations, not deterministic equality
or a stable before/after speedup. No claim of stable 60 FPS is supported.

Additional validation: scheduler cancellation/reentrancy boundary, slot reuse,
pause/resume, owner disposal, and dense cleanup passed; pixel combat effects
(27), dense combat regression (37), elemental reactions (69), and parameter/
chain selection regression (43) checks passed. Headless editor import passed.
Two explicit type annotations were added to the concurrently edited baked
lightning path to fix GPU script compilation; that visual work is otherwise
outside this optimization pass.

## Third pass: water contact and translation reuse

Ordinary water contacts now avoid constructing the generic reaction input and
result dictionaries for each victim. Burning and slow-to-freeze contacts retain
the generic resolver. Callback-driven holy/dark flame and light reflection keep
their original feedback, audio scopes and RNG. Collision cache keys remove only
the common world translation, allowing equal relative shape placements to reuse
results while preserving both shape bases and mutation invalidation.

Alternating before/after runs (before, after, after, before), same 300 static
grubs and loadout, yielded these averages across the two runs for each version:

| Weapon | Before mean / p95 / max (ms) | After mean / p95 / max (ms) |
| --- | --- | --- |
| Hammer | 5.52 / 38.76 / 66.97 | 5.36 / 37.40 / 63.86 |
| Plasma | 9.69 / 56.05 / 86.16 | 8.98 / 52.24 / 68.16 |

Every run retained damage totals 168973 / 44847. These measurements supersede
the noisier initial single comparison for this pass. Plasma mean improved about
7%, maximum about 21%; peaks still exceed a 60 FPS budget. No visual changes,
effect suppression, damage merging or cross-frame damage deferral were added.

Validation: water settlement oracle 94 checks (three real enemy types, wet,
burning/holy/dark, slowed/frozen/light, death, out-of-range parameters and custom
wet callbacks); continuous contact 3349 checks; elemental reactions 69 checks;
pixel combat effects 27 checks. All passed. Registry-wide lightning fallback
remains: replacing it safely requires tracking collider extents and child-shape
changes as well as enemy positions; a center-only spatial lookup could miss
large or offset colliders, so it was not substituted in this pass.
