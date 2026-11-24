# Two-phone co-op: connection screen and implementation stages

## Current status (2026-11-24)

**Network gameplay is not implemented yet.** New Game > Modem/Network Game
now opens a connection-only LAN lobby. It has Host Game, Join Game and Back,
using the original picture-2 backdrop, bitmap fonts, palette and menu engine.
Android activates the wider invisible row targets on release; dragging off
cancels. Desktop mouse, keyboard and controller navigation remain available.
All text is localized in the six game languages.

The maintainer approved this first screen on 2026-11-24 ("looks good, continue")
and required the entire implementation plan to be documented before more code.
That is visual approval, not a two-phone gameplay test. Do not interpret a successful connection as playable co-op,
simulation synchronization, matching mods, or Android device validation.
The screen explicitly labels itself as a connection test.

## Check the first screen

Use two instances of the current source project on the same LAN, or two phones
with an APK built from this checkout. An older APK does not contain this screen.

1. Connect both devices to the same Wi-Fi or a phone hotspot. Guest Wi-Fi/client
   isolation may prevent devices from reaching each other.
2. Open New Game > Modem/Network Game on both devices.
3. Choose Host Game on one. Its local IPv4 addresses appear below the status.
   Use the address belonging to the shared Wi-Fi/hotspot network; a device with
   VPN or other adapters may have multiple addresses.
4. Choose Join Game on the other. Type the host's IP address, then press Enter
   on the keyboard. Android opens the system keyboard; the address stays near
   the top of the original screen. Tapping the address opens the keyboard again.
   Escape/controller Back cancels editing; tapping outside the address also
   cancels. Addresses are literal IPv4/IPv6, without a port or hostname.
5. Both screens should report connected, with gameplay explicitly unavailable.
   Disconnect, Stop Hosting or Back releases the connection. Back returns to
   Players. Suspending the Android application also closes the connection.

The LAN transport uses UDP port **26635**, one guest, and a reliable ENet hello
containing a lobby protocol version and application version. Socket creation,
bad addresses, connection/handshake timeout, disconnect and incompatible hello
errors are shown on the same screen. It does not use Godot scene/RPC replication,
deserialize objects, write player files, or change the simulation.

The hello is only a connection-protocol check. The application's release version
is not a source/content fingerprint; gameplay must not start on its evidence.
There is no discovery, room code, NAT traversal, relay or internet service yet.

## Complete implementation plan

Recorded **before further implementation on 2026-11-24**. This is the execution
plan and progress ledger for the entire requested feature, through working
internet co-op. Update it when implementation evidence changes a decision;
do not silently reduce the objective to a connection demo or LAN-only game.
Stages may share internal code, but their exit criteria remain separate.

### Target behavior and boundaries

- Two Android phones each display the game and control one original co-op ship.
  One phone creates the session, owns configuration/progression, and occupies
  player 1; the joining phone occupies player 2. Both run the Rust simulation.
- First playable milestone: a complete original two-player Arcade level over
  Wi-Fi/hotspot, then Arcade campaign progression and two-player Endless.
  Network co-op uses the existing two-player modes and their equipment/economy;
  it does not invent a two-player version of one-player Full Game rules.
- Final milestone: the same session works across separate internet connections,
  with direct traffic where possible and TURN fallback where necessary. No
  dedicated simulation/game server. Signaling and relay infrastructure are
  still required for dependable connectivity; do not label that server-free.
- Preserve local desktop play, keyboard/mouse/gamepads, Android touch/tilt,
  original linked-ship behavior, and the original game mechanics. Desktop peers
  are useful test clients; cross-platform compatibility is a tested capability,
  not something inferred from the presence of networking code.
- No account system, public matchmaking, spectators, voice chat, host migration,
  mid-level joining, automatic mod downloads or arbitrary remote file writes.
  Reconnection initially returns to a lobby/restart flow, not speculative resume.
  Rollback/prediction is deferred until measured latency justifies a separately
  reviewed design. LAN discovery is optional after manual-IP LAN play works.
- No commits without a fresh express request. No paid service signup or public
  service deployment is implied by implementing the feature. Prepare service
  code/configuration and local verification first; request any missing hosting
  choices/credentials only when needed for a concrete deployment.

### Architecture and ownership

| Component | Responsibility | Existing implementation to inspect |
|---|---|---|
| Transport adapters | Reliable connection/control traffic; bounded input packets; lifecycle events; direct/relayed route reporting | `lan_lobby.gd`, ENet; later native WebRTC data channels |
| Protocol and session coordinator | Versioned schema, peer roles, session epoch, compatibility, start barriers, timeouts and disconnect state | New transport-independent GDScript modules and session tests |
| Input frame buffer | Per-tick complete input frames for both players; bounded storage; duplicates/order validation; no prediction | New pure GDScript module, exercised without Godot scenes |
| Rust simulation bridge | Apply each player's exact digital/mouse/analog inputs; expose consistent state fingerprints | `tyrian-godot`, `tyrian-sim`; original mouse/device semantics need audit |
| Level integration | Sample local controls, submit future frames, step only complete ticks, display/audio once per executed tick | `level.gd`, `touch_flight.gd`, tilt/weapon controls, `level_hotkeys.gd` |
| Progression integration | Ordered host-owned choices and common resulting configuration at each scene boundary | `game.gd`, `new_game.gd`, `shop.gd`, debrief and Endless session scripts |
| Internet bootstrap | Room creation/join, expiring signaling sessions, STUN/TURN configuration, short-lived relay credentials | New local-testable signaling service and deployment documentation |

The LAN adapter must remain usable while internet integration is developed.
Transport replacement must not redefine tick numbering, player roles or inputs.
Use explicit bounded data messages, not scene/RPC replication or object
deserialization. Keep gameplay in Rust and network/session coordination outside
the simulation. New game-state hashing must be independent of presentation.

### Stage 0 — Document and preserve the baseline

- [x] Record this complete plan before further code implementation.
- [x] Record approval of the first screen and retain its existing tests/captures.
- [ ] Keep a ledger of each later stage's actual tests, remaining gaps and any
  required decisions. Existing uncommitted networking work belongs to this task;
  preserve unrelated changes if they appear during the work.

### Stage 1 — First connection screen (implemented; visually approved)

- [x] Original-style Host/Join/Back screen, Android release targets, original
  desktop navigation, localized errors and visible address entry/cursor.
- [x] One-guest LAN connection, bounded version hello, timeouts, cleanup and
  Android network permission. Automated real localhost ENet tests pass.
- [ ] Validate this on two Android devices as part of the phone milestone.

Exit evidence so far: 29 networking/Players/New Game tests passed; localization,
glyph, width, GDScript lint and framebuffer captures checked. No phone build
was delivered and no Android two-device test was claimed. The existing
`new_game.gd` gdformat failure also occurs on its HEAD baseline.

### Stage 2 — Define the shared protocol and buffered inputs

1. Define separate lobby-connection and gameplay protocol versions. Give every
   session and level a host-generated identity/epoch so stale packets cannot
   enter a replacement run. Require explicit player roles and message senders.
2. Define strict messages for compatibility/configuration, ready/start,
   tick inputs, state checks, pause/resume, progression and session termination.
   Include size/type/range limits; reject unknown fields/types, non-integral
   tick values, conflicting duplicates and out-of-window inputs. Disable object
   deserialization and cap both queued frames and work performed per poll.
3. Implement a transport-independent frame buffer: each player supplies one
   complete input frame per tick; only consume the next tick when both exist.
   Repeated identical frames are harmless; conflicting repeats fail the session.
   Out-of-order packets may fill future slots but never skip or repeat a tick.
4. Store digital masks, mouse buttons/deltas, analog axes and any simulation
   one-shot flags explicitly. Audit their actual bridge ranges before freezing
   the wire schema. Do not encode touch target screen coordinates as simulation
   state or reduce touch movement to approximate digital/analog movement.
5. Start with a small common input delay negotiated before a level. Prefill only
   the agreed neutral startup ticks. Each peer samples once per scheduled input
   tick; a stalled simulation must not resubmit different inputs for that tick.
   Tune the delay from measured RTT/jitter at later milestones, with a cap and
   a clear latency limit. Do not advertise a guessed value as phone-tested.

Exit: pure protocol/buffer tests cover order, delay/prefill, duplicate/conflict,
stale epoch, invalid/malformed data, bounds, empty waits and bounded retention.
These primitives alone do not enable gameplay or justify enabling Start.

### Stage 3 — Audit and preserve player-specific input semantics

1. Read current Android gameplay-preservation policy, parity/divergence sources,
   player movement/linking code and bridge setters. Inspect `c-final` where
   current code/documentation cannot establish the original behavior.
2. Trace digital, mouse, analog, fire/mode/sidekick/special inputs for both
   existing co-op players. Identify the shared mouse state and original player
   device assignments, special ownership, linked-ship behavior and edge flags.
3. Write down the smallest player-specific routing change and its equivalence
   evidence. If mechanics equivalence remains uncertain, present findings and
   obtain express approval before implementing the affected change (AGENTS.md).
4. Implement per-player input delivery with existing clamps, inertia, speed
   limits and action semantics. Leave the original local APIs/defaults intact.
   Each phone's touch/tilt and weapon controls target its assigned ship.
5. Verify equivalent old/new input paths tick for tick for each supported
   device assignment, both player roles, diagonal movement, boundaries, held
   fire, release/cancel, specials, linking/unlinking and death/respawn.

Exit: relevant Rust/bridge tests and covered strict golden parity pass. Explain
the limits of C reference coverage; new two-phone scenarios are rewrite
determinism tests, not new independent C evidence.

### Stage 4 — Compatibility, common configuration and start barriers

Frontend direction chosen by the maintainer on 2026-11-24: **reuse the original
host Episode and Difficulty screens while the guest waits in the lobby, followed
by a Ready check on both phones**. Do not replace this with new lobby pickers or
a fixed Episode-1 preset. Implement/review the host Episode screen first, then
Difficulty, under the one-screen-at-a-time policy. The choice authorizes this
flow; it is not evidence that either screen or a readiness barrier is wired.

1. Fingerprint the simulation/protocol build and actual gameplay content:
   original runtime data, enabled mod definitions and gameplay asset inputs.
   Specify canonical ordering and byte hashing. Hash file contents, not paths,
   timestamps, an editable release label or just mod folder names. Cosmetic
   preferences may differ only after auditing their effect on simulation.
2. Host proposes immutable mode/episode/level/difficulty, initial equipment and
   money/lives, mutators/gameplay settings, seed, player devices and input delay.
   Validate all fields against local content/rules. Guest explicitly accepts
   the same configuration fingerprint. Never silently replace local mods.
3. Negotiate compatible configuration, load the same level independently, then
   compare initial state/configuration fingerprints. Start only after both are
   ready for the same epoch; timeout/cancel returns to a clean lobby.
4. Reject old clients, mismatched builds/content/settings, duplicated role
   claims and unsupported modes with actionable localized errors. Freeze mod
   changes and local progression while a negotiated run is active.

Exit: two-process tests accept matching peers and reject each mismatch; slow
level loading cannot start one phone early. No readiness acknowledgement is
treated as permission to skip content or initial-state validation.

### Stage 5 — First playable LAN level

1. Add a persistent session owner across scene changes without replacing the
   local-play path. Reuse ENet through the shared protocol adapter.
2. Feed the agreed seed/configuration and exact input pairs into the existing
   35 Hz simulation. Advance once for each complete next tick, at the common
   pacing; never advance on missing input, predict, drop ticks, substitute a
   peer's last input or change a tick's movement/damage/RNG rules.
3. Audit `Effects.consume_tick`, hitstop, speed controls, pause/overlay flags
   and settings that currently affect stepping or simulation. Presentation
   timing must not independently advance/skip a peer's simulation. Shared
   gameplay-affecting settings require explicit session agreement.
4. Keep rendering responsive while waiting; emit audio/effects only for executed
   ticks. Clear held inputs at focus loss/cancellation. Disable local cheats,
   quick-load/state replacement and unsupported shortcuts during a network run
   through explicit handling, while preserving their ordinary local behavior.
5. Compare state fingerprints at fixed common tick boundaries. Audit coverage
   of existing `state_hash`/snapshot groups; extend network state checking if
   relevant future state is omitted. A mismatch stops the session and records
   bounded local diagnostic metadata; never silently overwrite it to hide drift.

Exit: two processes complete the same two-player level with identical state
at agreed ticks, independently scripted inputs and both player roles exercised.
Then repeat on two Android phones with touch and tilt. Verify responsiveness,
CPU/battery behavior and focus loss. A desktop loopback run is not phone proof.

### Stage 6 — Shared pause, termination and recovery

1. Ordered session-control sequence numbers and agreed simulation boundaries
   coordinate pause/resume and level exits. No peer advances past an agreed
   pause boundary while its partner is paused or displaying a blocking menu.
2. Input/network stalls freeze simulation while the connection is evaluated;
   bounded timers give clear waiting/disconnected states and a safe exit.
   Android background/suspend cannot leave the other ship firing indefinitely.
3. Initial disconnect recovery terminates the active run cleanly and offers
   lobby/restart. Do not fake a seamless resume, transfer host ownership or
   apply old-epoch packets to a new run. A future resume needs snapshots and
   another reviewed protocol.

Exit: pause requests from either role, simultaneous requests, backgrounding,
lost Wi-Fi, host loss, guest loss, quit/cancel and repeated host/join cycles
leave no stuck input, leaked sockets, divergent ticks or unwanted profile writes.

### Stage 7 — Arcade campaign, menus and persistence

1. Synchronize progression as ordered host-owned decisions with guest intent
   messages where the original mode permits guest choices. Host validates
   purchases/equipment changes against the existing Rust shop rules; both
   verify resulting equipment/money and the same progression sequence.
2. Cover level results/debrief, Arcade shop/options, loadout, next level,
   episode transitions, bonus/secret routes, game over and ending. Both peers
   pass a new load/start barrier for every gameplay scene.
3. Preserve the original screen artwork/layout and controls. Adapt one menu
   screen at a time; present concrete directions before new frontend designs
   and allow maintainer review before changing the next screen. The approved
   overall direction reuses Network Game and original-style Host/Join screens.
4. Define host-owned campaign save identity and atomic persistence using current
   save APIs. Guest settings stay local; no guest save slot is overwritten.
   Network save/resume starts from a common negotiated checkpoint, not an
   unsynchronized local quick-load. Unsupported saves/actions must be explicit.
5. Agree achievement/statistics/replay treatment: evaluate original achievements
   from executed deterministic ticks, avoid duplicate transition rewards, and
   version replay metadata to retain both players' inputs/session configuration.
   Do not label a recording playable unless playback has been tested.

Exit: network player journeys verify money/equipment/files and both peers'
state, not just matching screenshots. Complete a multi-level campaign route,
death/retry and save/restart without changing ordinary local save behavior.

### Stage 8 — Two-player Endless and mod coverage

1. Carry the same protocol through wave selection, lives/equipment, difficulty
   changes, combos, shared seeds and deterministic RNG. Review Endless's
   separate run/profile state instead of assuming Arcade integration covers it.
2. Coordinate end-of-run, summary, retry and leaderboard/profile ownership.
   Keep scores honest about mode/content and prevent duplicate persistence.
3. Test originals, each shipped pack and all five together, plus mismatched
   or missing enabled packs. Include original linked ships and alternate/special
   weapon controls. Only support mutators whose shared state has been audited.

Exit: two-phone multi-wave runs and restart/results tests agree at checkpoints;
each supported mode is explicitly listed. Unsupported side modes stay disabled.

### Stage 9 — Native WebRTC and local internet-service prototype

1. Verify native WebRTC extension availability for Godot 4.7.2 and Android ARM64,
   matching desktop test targets, dependency licenses, ABI and 16 KiB alignment.
   Build a minimal two-peer data-channel probe before integrating it. If no
   suitable maintained binary exists, document/build the extension rather than
   pretending built-in browser support applies to Android.
2. Implement a transport adapter with the same session/input protocol. Separate
   control traffic from tick input where useful; preserve the complete-input
   and bounded-buffer guarantees regardless of data-channel delivery policy.
3. Implement a small signaling service with create/join room codes, exactly two
   roles, expiring rooms, bounded SDP/candidate/message sizes, rate limits,
   secure random join secrets and cleanup. Test it locally, including wrong/
   expired/full rooms and disconnects. Do not expose arbitrary host forwarding.
4. Configure STUN discovery and authenticated TURN fallback. Use short-lived
   relay credentials issued by the service, not a permanent TURN password in
   the APK. Use TLS for deployed signaling and restrict relay access/quotas.
   Avoid retaining SDP/IP information or secrets in routine logs.
5. Prepare reproducible service configuration, environment-variable examples,
   health checks, deployment/rollback instructions, resource limits and an
   estimate based on measured relay traffic. Keep secrets out of Git and builds.

Exit: local service and native data-channel tests connect through direct and
forced-relay paths using the existing game protocol; internet dependencies
and hosting configuration are concrete and reviewable before deployment.

### Stage 10 — Internet room flow and deployment

1. Select/configure a real reachable signaling/TURN host or managed services,
   obtaining missing hosting choices/credentials and any deployment approval
   only after the prepared result can be reviewed. No dedicated game server is
   introduced; relay bandwidth remains a real operating dependency/cost.
2. Extend the approved original-style lobby with internet create/join codes,
   keeping manual-IP LAN available. Present specific layout choices before
   implementation and review one changed screen at a time. Expose clear
   connecting/ready/error status, latency and direct/relay information where
   useful; do not put technical credential configuration into normal player flow.
3. Ensure connection/authentication, session compatibility and gameplay
   start barriers are the same for LAN, direct internet and relayed traffic.
   Failed direct connectivity must try the configured relay or report failure;
   never promise universal NAT traversal without a working relay path.

Exit: two actual phones on separate networks complete sessions over both direct
and forced-relay routes. Verify Wi-Fi/Wi-Fi, Wi-Fi/mobile data and mobile/mobile
where available; record tested carriers/networks without generalizing coverage.

### Stage 11 — Adverse-network, platform and release validation

1. Automate two-process journeys with controlled delay, jitter, loss, duplication,
   reorder, outages and malicious/malformed messages. Check eventual ordered
   progress or explicit bounded failure, identical accepted ticks and bounded
   memory. Measure input delay/RTT rather than assuming buffered play feels good.
2. Exercise both Android roles, touch/tilt, keyboard visibility, screen rotation
   policy, app switching, suspend/resume, network change, long sessions,
   reconnect/rehost and multiple enabled mods. Inspect logcat for errors and
   measure native performance/battery/thermal behavior on available devices.
3. Run relevant Rust tests, strict covered parity, robustness and gdUnit suites;
   locale/glyph/width checks, original UI regressions and changed-code lint.
   Include local desktop co-op, single-player and Android single-player
   regressions. Inspect captures and actual saved state/profile effects.
4. Run the exported Linux package gate from `docs/testing.md`: full player
   journeys before handing over any game build, then player-smoke on the same
   HEAD and working tree. WSL is currently unavailable on this host; report the
   blocked gate and arrange a suitable environment instead of claiming success
   or silently waiving it. Respect this prerequisite for APK handover too.
5. Build/package Android with native dependency alignment, required permissions,
   notices and configured endpoints; test clean install and upgrade. Keep debug
   signing versus release distribution explicit. Update public claims and all
   language READMEs only to the capability actually verified.

Exit: a reproducible, tested two-phone internet co-op build; documented service
operation, supported modes, tested devices/networks, latency limits and known
limitations; all required gates passed or explicitly unresolved, never hidden.

### Execution ledger after first-screen approval

| Stage | Status | Evidence / next action |
|---|---|---|
| 0 | Plan documented | Full plan written before further implementation, 2026-11-24 |
| 1 | Implemented; visual review accepted | 29 tests and original-framebuffer review; phone test pending |
| 2 | Input/control primitives implemented | 13 codec/buffer tests pass, including a 500-tick adverse-delivery pair; configuration/progression payloads remain for stages 4/7 |
| 3 | Core and bridge routing verified; phone integration pending | 5 Rust routing tests, 2 native bridge tests, strict covered parity and existing touch-control regression tests pass; phone HUD/session integration remains |
| 4 | Design selected; implementation next | Host uses original Episode then Difficulty screens; guest waits; both confirm Ready; content/build/configuration checks still required |
| 5–8 | Pending | LAN play, session control and progression |
| 9–10 | Pending | Native WebRTC probe, local services, deployment and internet room flow |
| 11 | Pending | Adverse-network/device tests and exported-package gate |

### External references and unconfigured infrastructure

Native Godot WebRTC requires an additional GDExtension; verify Android ARM64
packaging, engine compatibility, licenses and 16 KiB alignment before selecting
its release. See
[Godot WebRTC support](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html)
and [WebRTC connection setup](https://webrtc.org/getting-started/peer-connections).
No service endpoint or TURN credentials have been configured or deployed.

## Gameplay wire primitives (stage 2)

`network_protocol.gd` is independent of the connection-only lobby's JSON hello.
It is not yet attached to a game session. The binary packet layout uses explicit
little-endian fields and exact packet sizes. No generic Variant, object or JSON
decoder is involved. Unknown kinds/flags, extra bytes, truncation, wrong versions,
invalid role claims and stale session/epoch are rejected.

| Offset | Field | Encoding / constraints |
|---|---|---|
| 0 | Magic | Four bytes `OT2N` |
| 4 | Gameplay protocol | u16, currently 1; distinct from lobby hello version |
| 6 | Kind | u8: input 1, state 2, ready 3, start 4, pause 5, leave 6 |
| 7 | Sender player | u8, 1 host or 2 guest; adapter must supply the authenticated expected role |
| 8 | Session | 16 bytes; represented as 32 lowercase hex characters in local code |
| 24 | Level epoch | u32, 1..4294967295; allocated by future session coordinator |
| 28 | Tick | u32, 0..4294967295; no wraparound within an epoch |
| 32 | Control sequence | u32; zero for input/state, nonzero for ready/start/pause/leave |
| 36 | Payload | Exact kind-specific data below |

Input packets are 56 bytes: u16 digital mask (bits 0..9 only), u8 mouse mask
(bits 4..7 only), u8 new-key flag (0/1), then four i32 values for mouse dx/dy
and reduced analog x/y. Values are preserved exactly, not rescaled or clamped
by the codec. Signed-32-bit is the bridge's representation, **not** an approved
physical-input range: the future session adapter must validate negotiated
device-specific limits and safe combinations before applying them to Rust.
Android touch/tilt currently produces deltas in -30..30; reduced gamepad axes
come from `controls.gd:analog_axis_reduce`. Encoding does not confer permission
to apply arbitrary remote i32 values to simulation arithmetic.

State/ready/start packets are 68 bytes with a 32-byte digest. Digest generation,
configuration validation and readiness barriers belong to stages 4/5; a valid
packet alone proves none of them. Only host-role packets can carry Start.
Pause packets are 37 bytes with request-pause/commit-pause/request-resume/
commit-resume codes 0..3; only the host can commit. Leave packets are 37 bytes
with quit/timeout/desync/incompatible/protocol-error reason codes 0..4.
Stateful sequence enforcement, progression choices and configuration manifests
are deliberately not implemented by this data codec.

`network_input_buffer.gd` holds at most 128 upcoming ticks per player and 128
consumed tick pairs for duplicate checks. It prefills only the negotiated
neutral startup ticks. The current input-delay bound is 0..8 ticks for prototype
configuration; it is not a measured recommendation. Use `needs_local_input()`
before sampling hardware. Capturing again while waiting returns a copy of the
original frame, preserving one-shot flags and mouse deltas. Only `take_tick()`
with a complete next pair produces data for a future simulation step.

Identical duplicates are idempotent before/after consumption; conflicting
duplicates stop consumption until reconfiguration. Old packets outside retained
history are discarded as stale. Wrong epochs, wrong roles, invalid messages and
far-future input cannot allocate slots. The coordinator must turn protocol
violations into the appropriate session error; the buffer does not advance a
simulation, own a socket, implement timeouts or authorize a level start.

## Approved player-input adaptation and audit (stage 3)

On 2026-11-24 the maintainer expressly approved separate per-player touch/mouse
input routing for network sessions, retaining existing movement calculations,
linked-ship rules and weapon ownership. This approval followed the investigation
below, not an assumption that two independent pointing devices already existed
in the original game.

- `player.rs:read_player_controls` reads one `mode.mouse` and clears one
  `mouse_pending` flag after the first eligible player consumes the delta.
  Simply assigning mouse-capable device 0/2 to both players cannot move both
  ships independently. The current Android path targets player 2 in two-player
  mode, but Android's local two-player launch remains disabled.
- The new opt-in `Sim.set_player_mice(Some([p1, p2]))` selects a separate source
  and pending flag for each player. The existing device gates and all movement,
  clamping, inertia, bounds, button mapping, linking and firing code remain in
  use. `None` restores the original shared accumulator; local play defaults to
  None. Godot exposes `set_player_mice` and `clear_player_mice` for later session
  integration; replay playback ignores the new setter.
- Equipped specials remain owned by player 1 (`do_special_shot` and bridge
  digital-mask bits 8/9); sidekick/rear-gun behavior remains with its original
  co-op player. No guest special is added and no cross-player action remapping
  is implemented. Phone HUD ownership/adaptation remains future work.
- Rust tests compare snapshots, golden-style frame records and mode records
  tick for tick against the existing shared path, with each player taking the
  mouse role in turn. They also cover simultaneous opposite movement, the
  original clamp/inertia, clearing the override and a fixture that actually
  links the ships and exercises gun rotation/unlinking. These checks test the
  scoped implementation, not every possible two-pointer linked-play scenario.
- `c-final` is absent locally and not advertised by the canonical remote's tag
  listing; no C history is available in this checkout. No independent C
  recording was made. Existing frozen golden tests remain the local-play
  regression evidence; new network tests are rewrite equivalence tests only.

Existing snapshot/state hashes omit some future-affecting fields, including
input/device state, so stage 5 must still audit/extend network fingerprint
coverage. Adding input routing does not make the old snapshot a complete
network resynchronization format. No snapshot-based resume is enabled.

### Validation evidence for stages 2–3 (2026-11-24)

- The 13 new codec/buffer tests pass. The paired-buffer delivery test produces
  identical input sequences for 500 ticks despite scheduled jitter, reordering,
  duplication and delayed retry, while checking queue/history bounds.
- All 5 new Rust mouse-routing tests pass, as do 2 native Godot bridge tests.
  The Windows GDExtension was rebuilt locally for the bridge checks; it was not
  packaged or handed over as a game build.
- The relevant Godot selection totals 52 cases: protocol, buffer, bridge, LAN
  lobby, network screen, Players, New Game and existing touch weapon controls.
  The intentionally occupied-port test checks ERR_CANT_CREATE and socket cleanup;
  only that synchronous expected native error has printing suppressed, with
  Engine.print_error_messages restored immediately afterward. Unexpected error
  lines still fail log verification.
- The unfiltered release simulation library run reports 122 passed, 3 failed,
  1 ignored. An isolated unchanged-HEAD worktree reproduces the same failures:
  `destruct::tests::default_config_file_matches_c` (CRLF/LF fixture difference),
  `f32ops::tests::sincos_match_hardware` and
  `f32ops::tests::sincos_large_match_hardware` (Windows hardware math versus the
  fixed reference calculations). The temporary baseline worktree was removed
  after checking it was clean. No unrelated arithmetic/configuration fix was
  folded into networking.
- Running release simulation tests with exactly those three confirmed baseline
  tests excluded passes **155 cases**, with 1 existing ignored case. This is
  qualified Windows evidence, not a green unfiltered suite or Linux gate.
- The golden baseline regression test passes. Strict original-input replays for
  `e1-tyrian-autopilot` and `e2-first-autopilot` pass **13,391/13,391 ticks** and
  matching level ends. This does not establish independent C parity for two
  pointing devices.
- Cargo formatting passes. Strict current-toolchain Clippy reports existing
  `needless_range_loop` diagnostics in unchanged loops and
  `mem_replace_with_default` in unchanged shop code. A diagnostic-only rerun
  allowing precisely those two lint categories passes; strict Clippy remains
  unresolved. The existing `new_game.gd` gdformat issue remains too.
- New/changed networking GDScript uses the repository's lint/formatter settings.
  Documentation links and diff whitespace are checked. Android device tests,
  APK handover and the exported Linux package gate have not run; WSL remains
  unavailable. Co-op is still not playable from the lobby.

## Validation

`rewrite/godot/test/lan_lobby_test.gd` opens real localhost ENet peers and verifies
handshake, disconnect/rehost, bad address/port, port conflict, timeout, incompatible
hello and application suspension. `network_lobby_test.gd` covers the Players entry,
touch press/release and cancellation, address entry/cancellation, Back cleanup,
desktop targets and all translated text widths. Existing Players and New Game
suites cover the changed entry and unchanged local flows.

Run these through gdUnit4 with an isolated player directory as described in
[Testing](testing.md). `Capture` accepts `--capture=network_lobby:<file>:20`
for original-framebuffer visual review. These checks do not replace two-phone
Android testing or the exported-package gate before handing over a game build.
