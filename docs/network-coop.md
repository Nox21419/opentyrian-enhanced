# Two-phone co-op: connection screen and implementation stages

## Current status (2026-11-26)

**The source now includes an Android-only LAN co-op prototype with supported
level continuation. It has
not been verified on two phones.** New Game > Modem/Network Game opens a LAN
setup lobby. It has Host Game, Join Game and Back,
using the original picture-2 backdrop, bitmap fonts, palette and menu engine.
Android activates the wider invisible row targets on release; dragging off
cancels. Desktop mouse, keyboard and controller navigation remain available.
All text is localized in the six game languages.

The host Episode and Difficulty checkpoints are implemented and approved: while hosting,
Join Game becomes **Choose Episode**. It reuses the original Episode screen and
then opens the original Difficulty and two-player Arcade Game Menu screens.
Start records host intent and returns to the same live lobby with both choices
shown. It does not launch gameplay. Back preserves the host connection;
leaving the lobby stops it and clears both choices. No campaign save is written;
the host's original Options screen may save local audio preferences. Options
is approved along with the preceding host screens. The shared lobby Ready check
is also approved: both confirm the agreed configuration and only the host can
Start. The player-menu handoff now opens the original full two-player view,
finishes the original entry fade and waits for both views before advancing.
Assigned Android touch/tilt input and session-owned effects/pacing drive the
prototype clock. Source tests cover both roles at Normal/Turbo, matching 60
per-tick diagnostics, Back/focus exit and clock restoration. Either phone now
requests synchronized Pause using Back or the original touch pause target.
The host operates the original Pause menu; the guest sees PAUSED. Host-local
Music/Sound, Return and Quit work; negotiated settings and unsupported rows stay
dim. Host Return resumes both; guest Back while paused leaves. Focus loss,
disconnect closes this prototype session and returns to the lobby. On agreed
level completion, surviving players now see the original two-player debrief and
Statistics on both views, with host-only advancement. Both final fades finish
before agreeing a supported shop/direct-level continuation. The host reuses the
original Arcade menu while the guest waits, then both load/compare and adopt a
fresh level in a new epoch before their next views become ready. Normal all-dead
results exit after agreement without a successful debrief. Story/autosave effects,
retry, bonus-death and episode-ending routes, naturally won multi-level and
independent-process lifecycle journeys, physical phone verification and internet
integration remain unfinished. Unsupported routes exit explicitly. Desktop networking remains a
diagnostic transport/backend profile, not a shipped desktop input profile.
The previously observed intermittent Windows shutdown access violation remains
unresolved. No new APK or playable build has been handed over.

The maintainer approved this first screen on 2026-11-24 ("looks good, continue")
and required the entire implementation plan to be documented before more code.
That is visual approval, not a two-phone gameplay test. Do not interpret a successful connection as playable co-op,
simulation synchronization, matching mods, or Android device validation.
The screen now labels this as a first-level LAN test.

## Remaining work after synchronized Pause (2026-11-25)

The following work remains in addition to physical-device testing, in this order:

1. **Level completion and progression (started).** Both phones show the original
   two-player debrief/Statistics; the host advances and the guest waits (chosen
   by the maintainer on 2026-11-25). Follow with the already approved host-operated
   original Arcade menu. Preserve both players' money, earned equipment, lives,
   survivor state, difficulty adjustment and campaign-script routing. Cover
   ordinary/bonus/secret levels, game over/retry and episode endings. Two-player
   Arcade has no purchases. Each next level requires a fresh agreed input epoch
   and load/view-ready barrier. Work on one frontend screen per review.
2. **Internet bootstrap.** Implement the documented peer connection flow beyond
   literal LAN addresses, including signaling/NAT traversal and relay fallback
   where direct mobile-network connections fail. No dedicated game simulation
   server is required. Do not label the current LAN prototype internet-ready.
3. **Failure handling and lifecycle.** Complete timeouts, disconnects and clean
   exits at every transition; investigate the intermittent Windows native
   shutdown access violation and prove repeated independent-process cleanup.
4. **Automated network verification.** Add separate-process, extended-session,
   multi-level and adverse-network journeys. Check resulting state and files,
   including no accidental local campaign/profile writes. Matching pictures
   alone do not prove progression or preserved equipment.
5. **Packaging.** Run the exported Linux package journeys and smoke gate when
   WSL/Linux is available; verify Android identity/native-library/assets packaging
   before handing over an APK. Internal source tests are not package validation.

### Level-completion implementation plan

1. Audit the original local completion path and native carry/load APIs before
   changing network behavior. Extract a detached, read-only result record at the
   final fully presented tick, including both players and the existing carry
   payload. Verify extraction does not change core diagnostics/RNG or Game.
2. Add bounded, role/epoch-bound result agreement separate from pause controls.
   Stop capture/stepping at natural completion; compare the exact final tick,
   complete diagnostic and canonical result digest before showing debrief.
   Tolerate valid duplicates/stale epochs and fail closed on conflicts/timeouts.
3. Reuse the original debrief and detailed Statistics renderer with explicit
   session inputs instead of assigning Game's local campaign globals. Both show
   the agreed result; host continuation controls the shared transition. Keep the
   original fonts, animation, two-player cash rows, artwork and touch footer.
   Define presentation-only elapsed time consistently without changing ticks.
4. Audit and implement a session-owned campaign cursor using existing script,
   difficulty and carried-state rules. Preserve secret/bonus branches and
   survivor/game-over behavior. Never loosen initial-start validation to accept
   arbitrary client-proposed progression or write local saves as a side effect.
   If carry/loading equivalence remains uncertain, explain the evidence and
   obtain express mechanics approval before implementing that adaptation.
5. Bind the original host Arcade menu to the agreed continuation, keep the guest
   waiting, validate the resulting next-level configuration/carry on both peers,
   prepare fresh owned simulations and cross the load/view barriers. Dispose old
   views before freeing their borrowed native nodes. Do not reset an active
   simulation or reuse old input packets across levels.
6. Test natural completions, duplicate/reordered controls, mismatched results,
   disconnect during debrief/loading, host-only advance, preserved carry/cash,
   special routes, retry/episode end and repeated level transitions. Compare to
   existing local rules and verify ordinary local debrief/campaign behavior.
   Record screen captures, process exit codes and unavailable checks explicitly.

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
5. Both screens should report connected.
   Disconnect, Stop Hosting or Back releases the connection. Back returns to
   Players. Suspending the Android application also closes the connection.

For the host Episode checkpoint, Host Game first, then Choose Episode. Choose
an available episode, then Difficulty, or Back; the connection remains open.
Reopening the screens restores selected rows. The host may make this preparation
choice before a guest connects. Arcade Start requests a configuration proposal
once a compatible guest is present. Both peers then validate/freeze content,
compare prepared simulations and explicitly confirm Ready. Host Start activates
the backend at tick zero, then opens the first-level player view on Android.
Both entry fades must finish and both views must acknowledge readiness before
either simulation advances. Hold a playfield finger to steer/fire (or use the
saved tilt option). Back closes the prototype session; synchronized pause and
later-level progression are not available yet. Accepted choices require
cancelling the session to change them. These are source-flow instructions,
not a claim of completed two-phone verification or an available new APK.

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
   equipment/progression changes against the existing mode rules; both verify
   resulting equipment/money and the same progression sequence. Two-player
   Arcade uses its original Arcade Game Menu, not Full Game purchases; do not
   introduce a purchase system into this mode.
2. Cover level results/debrief, Arcade Game Menu/options, loadout, next level,
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
| 4 | Backend tested; first host Episode screen awaiting review | Identities, configuration grammar, shared load/Ready/start barrier and real ENet adapter tested; persistent version-only lobby and original host Episode choice wired; Difficulty, catalog validation and full level-state integration remain |
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

## Compatibility and startup backend (stage 4)

The initial foundations and complete plan were committed and pushed to
`origin/main` as `cee40cf` on 2026-11-24 at the maintainer's express request.
That spent the one-commit authorization. The following continued implementation
is a separate working-tree change, not an additional authorized commit.

The ordinary Network Game screen still runs the connection-only lobby. It has
not been connected to the startup coordinator or a level, so its Connected
message still does not mean playable co-op. The selected original host Episode
screen is now a separate frontend review checkpoint; Difficulty follows after
that review, under the existing chosen direction.

### Four independent identities

`network_identity.gd:collect` obtains four SHA-256 values, all required:

- **Native:** `tyrian-godot/build.rs` hashes root-relative source names and bytes
  under every local native crate's `src`, crate manifests/build scripts, workspace
  manifest/lockfile, rustc version and explicit compiler flags. The resulting ID
  is embedded in the loaded binary and exposed by `TyrianSim.network_build_id`.
  It does not read mutable Git HEAD, file timestamps or the application version.
  Compiler flags and byte/line-ending differences can conservatively reject
  otherwise equivalent independent builds; cross-platform compatibility still
  requires tests. A matching ID is not client authentication or anti-cheat.
- **Client:** editor runs hash current `project.godot` plus `.gd`, `.tscn`,
  `.tres` and `.cfg` files under scripts, effects, scenes, config and the
  networking export plugin. Tests/generated import caches/player files are
  excluded. The `tyrian_networking` export plugin inserts a fresh
  `res://assets/network-client-id.json` directly into every exported pack,
  including manual editor exports. Exported clients read that stamp because
  compiled `.gdc` files need not retain source text. Missing/invalid stamps
  fail collection; no stale source-checkout stamp is reused.
- **Content:** `TyrianMods.network_content_identity` hashes the desktop/Android
  runtime-data allowlist and all regular files in the effective enabled mod
  roots selected by the actual Rust loader. Invalid enabled mods or resolution
  errors fail closed. The disabled/retired packs and repository-only catalogs
  are not inputs. Mod documentation/art is conservatively included; no cosmetic
  exception has been assumed. Root locations and timestamps do not enter the
  hash. A later session must freeze/recheck content around actual loading;
  hashing does not protect against external file edits during a run.
- **Engine:** a digest of the explicit major/minor/patch/status/build/hash fields
  reported by the running Godot engine.

File manifests sort names and hash `name UTF-8`, NUL byte, lowercase SHA-256
hex of the file's actual bytes, then LF. Native runtime manifests also include
the `manifest/runtime-version` domain entry. Reads are streamed. Manifests cap
files at 4096, traversed entries at 8192, nesting at 32 and bytes at 512 MiB;
native manifests reject symlinks/nonregular content and ambiguous names. Client
scans reject links/ambiguous names and require readable sources. These are
compatibility bounds, not new simulation resource limits.

The file inventory is not a serialization of cached resolved tables. Before
player-flow negotiation is enabled, preparation must refresh the loader and its
resolved caches on both peers, freeze mod/configuration changes, collect the
inventory, and recheck it around actual level loading. External edits after a
previous mod load must not allow old cached definitions to be presented as the
new on-disk content. This remains part of the pending game integration.

The identity collector is read-only. Native SHA-256 uses `sha2` 0.10.9;
the locked dependencies' own MIT/Apache-2.0 texts are preserved in
`rewrite/licenses/network-hashing-LICENSES.txt`. Both package paths include it.

### Startup configuration and wire schema

`network_configuration.gd` defines an immutable **Arcade-only** startup grammar:
mode, episode, level file, initial/actual difficulty, seed, both loadouts and
cash values, devices, input delay, mutators, processor type, game speed,
explosion style, hitstop, combos, dedicated-special input mode, particles and
screen shake. The original
two-player difficulty increment is explicit. Seeds and cash are 16-character
hexadecimal u64 values, avoiding JSON double precision loss. Equipment is ten
typed fields per player; loadout power bounds and device ranges are checked.
Endless and save-resume configurations are not silently accepted.

Grammar validation is not catalog validation. The coordinator requires a local
application validator on **both** peers. It receives a deep copy and must return
a boolean; unknown/missing equipment, unsupported content and level-load checks
must be supplied by the later game integration. A truthy string/value is not
acceptance. No currently visible Start action bypasses this unfinished work.

`network_startup_protocol.gd` uses a distinct `OT2S` prefix and schema version 2,
not the gameplay `OT2N` packets or original LAN JSON hello. Its body is a compact
ordered JSON array: version, kind, sender role and the kind-specific fields.
Object-key duplication cannot change a configuration because configurations
are ordered field arrays, too. Packets are limited to 2048 printable ASCII
bytes; malformed/non-ASCII data, fractional numbers, trailing fields, invalid
digests, unknown fields/kinds and wrong sender roles fail validation before
being accepted. No object/Variant deserialization occurs.

Hello carries native/client/content/engine digests. All other messages carry
session ID, nonzero epoch, nonzero sender-specific control sequence and the
configuration digest. Config adds the ordered proposal; Accept is guest-only;
Loaded/Ready/Start add the initial-state digest. Start is host-only. Config
and Ready are not gameplay input and never advance a simulation tick.

### Shared startup barrier

`network_startup.gd` enforces this sequence:

1. Both identities match before the host can propose configuration.
2. Host proposes immutable configuration for a session/epoch; both local
   validators must accept it, and the guest acknowledges the same digest.
3. Each caller explicitly reports its actual loaded-state digest. Both reports
   must match before either can confirm Ready. A slow loader cannot be skipped.
4. Both people explicitly confirm Ready. Only then can the host send Start,
   and the guest accepts it only for the agreed epoch/configuration/state.

Duplicate last controls are idempotent; conflicting repeats fail startup.
Out-of-order sequences are rejected, and stale session/epoch messages do not
consume a valid sequence. Compatibility/reply waits have an 8-second prototype
timeout; agreed loading has 30 seconds. Human selection and Ready confirmation
have no arbitrary deadline once the relevant machine barrier is satisfied.
Failures clear queued startup messages. No host migration or resume is implied.

The coordinator **does not derive a complete level-state digest**, load scenes,
change profile/settings, validate the entire equipment catalog or step a Sim.
The existing snapshot completeness audit in stage 5 remains mandatory. Supplying
a digest in a backend test is not proof of a real game-level loading barrier.

`network_startup_connection.gd` binds this protocol to real ENet peers.
`lan_lobby.gd` permits post-hello traffic only when an explicit receiver is
registered; ordinary connection-only screens keep rejecting it. Processing is
capped at 32 packets per poll, with a 2048-byte session payload cap. Sender roles
come from the transport assignment, not a claim in the packet. Incompatibility,
bad startup messages and disconnect stop the adapter; its `running` property
requires both a completed barrier and a live connection.

### Verification and remaining integration

Four native fingerprint tests cover byte sensitivity, path/order independence,
runtime allowlist behavior, enabled-content selection and manifest bounds.
Godot tests cover configuration precision/canonicalization, malformed wire data,
four identity mismatch categories, mandatory validators, duplicate/conflicting
controls, stale epochs, premature Ready/Start, state mismatch and timeouts.
Real localhost ENet tests run the entire startup exchange, reject incompatible
peers/bad packets and exchange actual loaded native/content/client identities.
Additional identity tests compare a cross-language hashing fixture and exercise
source additions, missing roots and stable native content collection.

An internal Windows resource-pack export was probed in a separate Godot process:
the embedded client digest matched the current loose source digest. This is an
export-metadata check, not a distributed/handed-over game build or Android proof.
Android bundle tests verify deterministic manifests and inclusion of the new
dependency notices. No APK, phone/network test, exported Linux package gate or
internet service deployment is claimed for this stage.

### First host Episode screen checkpoint

`NetworkSession` is a small persistent autoload owning the original version-only
LAN lobby and a temporary selected-episode value. `network_lobby.gd` hands that
connection to the original `new_game.gd` Episode screen through a one-shot flow.
Selecting an episode returns to the same lobby/peer object, shows the chosen
original episode label, and restores that row on reopening. Back cancels the
screen without stopping the host. Unexpected departure from the host Episode
scene or leaving the lobby closes the socket; the one-shot flow cannot leak
into an ordinary local new game. Android uses the existing wide release targets;
desktop keyboard/gamepad/mouse navigation remains the original menu behavior.

This menu state is deliberately separate from `network_startup_connection.gd`.
It does not supply a placeholder catalog validator, fake a loaded state, modify
Game's active campaign/episode, write a save, or advance into a local two-player
level. Choosing an episode only prepares the next host menu step. Difficulty
and Ready are not exposed as dummy actions.

`network_episode_test.gd` checks selection-on-release, exact peer preservation,
Back/exit cleanup, selected-row restoration, unchanged active game state and
normal-flow reset. Original-framebuffer captures show the original Episode
screen and the returned host lobby with Episode 3 selected. These are desktop
source captures, not Android phone validation or an APK handover.

Next after this screen's review: connect the original Difficulty screen and
actual catalog/configuration checks and level preparation, then bind the tested
startup coordinator to the player session. Keep gameplay disabled until the
complete state/start/input path is in place and verified.

Verification for the continued working-tree checkpoint (2026-11-24): **74/74
Godot cases** pass across 13 selected suites, with no error lines or orphan
nodes; **4 native fingerprint tests** and **3 Android bundle tests** pass.
Both strict in-app original-input replays pass (6,967 and 6,422 ticks reported
by the app capture path). The earlier Rust comparator's 13,391-tick count is a
different reference accounting path, not an added recording. The export stamp
was re-probed after the host Episode changes and still matches current sources.
Changed networking GDScript, Cargo formatting, Python lint/format, locale/glyph/
width checks, shell syntax and local documentation links pass. Clippy passes
with the same two previously identified baseline lint categories allowed;
unfiltered lint and the Linux package gate are not claimed green. No Android
device test or APK handover occurred.

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

### Host Difficulty screen checkpoint

The maintainer approved continuing from the Episode checkpoint on 2026-11-24.
Episode selection now opens the existing Difficulty screen. Selecting Difficulty
returns to the same host peer and shows both original localized choice labels.
Back returns to Episode; reopening restores both choices, including an unlocked
secret difficulty. Changing Episode clears the previous Difficulty. Stop/exit
clears both. Android retains the existing six rows and release-only touch input;
desktop retains the original three starting rows and secret unlock behavior.

This is preparation state only: no campaign start, gameplay tick, profile write,
Ready action or placeholder state digest is introduced. The next frontend step
requires review of this Difficulty screen; catalog validation and synchronized
level preparation remain the next backend work in stages 4/5.

The updated host-flow test checks release-only Difficulty activation, unchanged
active campaign, exact peer preservation, restored rows, Back and reset on a new
Episode. Existing local New Game and lobby suites are included in validation.
The source capture is desktop evidence, not an Android device test or build
handover. Linux package checks remain unavailable without WSL.

### Initial rules and campaign-entry audit

After Difficulty approval (2026-11-24), `network_initial_configuration.gd` adds
an initial-session policy usable as the startup coordinator's mandatory
validator. It reads fresh native campaign scripts into a separate RefCounted
instance and checks the actual default first-level destination for every
available episode/difficulty. It accepts only the existing two-player Arcade
starting equipment, zero money and the approved two mouse-capable devices.
This policy is separate from future progression/load/save configurations.

Investigation found that all five episodes first stop at the original shop.
The read-only level preview follows the same default map destination as
`Game.campaign_leave_shop`, but retains the complete entry-script result.
Validation does not apply that result, bypass the shop/story, load a level,
autosave, draw a seed or mutate Game. Before playable integration, the host must
go through the original shop and any resulting equipment/progression must have
its own ordered common configuration. No gameplay is enabled by this policy.

This is initial-rule validation, not complete catalog/asset validation. Remaining
work includes resolving/freezing effective mod tables, validating actual level
assets and equipped definitions, integrating initial shop/progression, preparing
both simulations and auditing full future-affecting state hashes. The source
fingerprint alone does not make cached resolved definitions current.

Verification: 15 cases pass across initial-policy, configuration and startup
suites, with no errors/failures/orphans. Tests cover all 30 episode/difficulty
pairs, the retained shop boundary, rule-invalid but grammar-valid proposals,
missing content, invalid choices, copied results and real-policy startup
acceptance without early Start. New GDScript formatting/lint and diff whitespace
pass. No phone test, Linux exported package gate or build handover is claimed.

### Session-owned content snapshot

`network_content_snapshot.gd` now captures content in a separate native mod
loader, with copied directory order and explicit enabled-folder choices. It
does not use or mutate the global Mods API, player preferences or Game state.
Newly discovered default-enabled folders are forced off; an explicitly enabled
folder disappearing is an error. Resolution errors and unreadable/changed
content fail closed. It hashes, discards resolved caches, then resolves and
hashes again before retaining the loader. Checks use a new loader each time,
so stale resolution caches cannot hide an edited manifest.

`attach(sim)` first verifies current content, then attaches the retained loader.
A detected mismatch invalidates the capture permanently; restoring old files
requires fresh capture and negotiation. The caller must verify again after
loading and discard any prepared simulation on failure. This is an independent
backend component, not yet bound to NetworkSession or its startup handshake.
It does not lock filesystem writers or provide an atomic filesystem snapshot.

The four new tests check global-loader isolation, copied selections, attaching
the native API, enabled-byte edits, persistent invalidation, recapture, disabled
edits, newly discovered folders, missing enabled mods, invalid JSON and reset.
Together with identity and initial-rule suites, 12 cases pass with no reported
errors, failures or orphan nodes. New GDScript lint/format and whitespace checks
pass. Full item/level validation, session wiring and complete state hashing are
still pending; no Android/device or exported Linux package check is claimed.

The first final check exposed a process-level access violation during teardown
after gdUnit had printed success. The new native suite now releases Music/Sfx
streams in its `after` hook, matching existing native/menu suites. The final
12-case run has an explicitly checked process exit code 0 as well as clean
assertion/error/orphan results; the earlier printed success was insufficient.

### Read-only level and equipment preflight

`TyrianMods.network_validate_level` parses the actual episode level/item data,
checks both ten-field equipment arrays against named resolved table entries,
and applies validated level-event overrides to a disposable LevelSetup. It
rejects absent/padded records, invalid powers/array lengths, missing levels and
invalid episode/level/difficulty bounds. Empty rear/sidekick/special slots remain
allowed. This initial-equipment preflight requires nonempty primary equipment;
future modes allowing other equipment must extend the policy deliberately.

No Sim is constructed or stepped, no RNG is drawn, and no campaign or save is
written. The temporary setup uses a disposable default loadout: the requested
loadouts are checked, not applied to active gameplay. Errors use bounded codes,
not remote paths or native error logging for malformed proposals/missing levels.

`NetworkContentSnapshot.validate_level` requires the configuration grammar and
captured episode, verifies current bytes before the native check and again
afterward. Content/preflight failure invalidates that capture. Initial-rule or
progression authorization is still independently required; a valid asset check
cannot skip the original shop, authorize a Start or prove complete state hashes.

The rebuilt Windows bridge is used by the Godot tests. Coverage includes all
five actual first-level files, both original starting loadouts, invalid item IDs,
empty arrays, missing levels, invalid episode, changed content and invalidation.
A separate case resolves all five shipped packs and validates their added ship
and weapon definitions. Native preflight does not change local load_level APIs.
Synchronized preparation, shop/session wiring and complete-state hashing remain
the next backend work. Android execution and the Linux exported-package gate
remain unavailable/unclaimed; the rebuilt DLL was not handed over as a build.

Final verification for this checkpoint: 24/24 cases across content snapshot,
identity, initial rules and startup pass, with no errors/failures/orphans and
explicit process exit 0. Cargo formatting, changed GDScript lint/format and
whitespace checks pass. Clippy passes with the same two previously documented
baseline lint categories allowed; this is not an unfiltered lint claim.

### Unified preparation context and remaining load audit

`network_preparation.gd` now owns one content snapshot and a fresh initial-rule
reader for an epoch. Its identity uses that snapshot's content digest through
`NetworkIdentity.from_content`, rather than the unrelated global Mods cache.
Its mandatory validator composes initial rules, actual assets/equipment and
before/after content verification. It retains copied configuration and original
campaign entry only after validation. Later changes to the accepted configuration
invalidate the context; returned dictionaries cannot mutate its retained state.
Content and client/native/engine identities are rechecked while preparing.
Failure clears the public identity/configuration/entry and requires recapture.

This context is exercised with real identities as both pure startup coordinators'
validators. They reach AGREED with the actual original shop entry retained;
Start is still refused because no loaded/Ready barrier is fabricated. It remains
an isolated backend component; the player-facing NetworkSession still owns the
connection-only menu flow. No simulation, scene, RNG or save is modified.

Read-only load audit found two issues that must be resolved before marking a
prepared simulation loaded:

- `Sim.snapshot`/the legacy state_hash serialize a subset of world state, not
  complete future-affecting state. Besides inputs/devices, it omits many player,
  script, enemy and mode fields. Do not reuse it as a complete network digest or
  claim resynchronization support. A separately versioned exhaustive state
  serialization must cover core RNG state, retained pending inputs, settings,
  tables/events and progression/bridge state that can influence later ticks.
- `set_effects` derives core modern-explosion activation from particles,
  screen-shake and processor detail as well as explosion style. Current startup
  configuration does not yet include all of these. Normal level loading also
  initializes stars through the bridge's process-global STARFIELD_MT, which
  advances with previous local play. Isolated preparation must audit and avoid
  dependence on differing process history without altering local-play behavior.
  Combo timing and the dedicated-special input path also require explicit
  application/range audit before loading the synchronized simulations.

These findings refine stages 4/5; they do not authorize an uncertain mechanics
change. No such change has been implemented in this checkpoint.

Verification: 23 cases pass across preparation, content, identity and startup
suites, with no errors/failures/orphans and explicit process exit 0. This includes
real-policy peer agreement without early Start, immutable returned values,
configuration-change invalidation and fresh recapture. Changed GDScript lint and
format checks pass. Device, exported-package and playable co-op evidence remain
pending.

Next settings step (before implementation): extend startup schema to negotiate
particles and screen-shake, both of which participate in the existing bridge's
core Modern-explosion activation. Bump the startup protocol version rather than
accepting old shorter configurations. Derive the existing core-effect options
without applying them to active gameplay. Preserve the local Arcade rule that
combos are off (the combos preference is only applied to an active Endless run).
Keep dedicated-special ownership in the tick input, not a new core-setting API.

### Explicit effects prerequisites in startup schema 2

The 21-field startup grammar now includes strict boolean particles and screen
shake values. Both affect the configuration digest and are required on each
peer. Startup protocol version 2 rejects old hello versions and old 19-field
configuration arrays; gameplay packet and original connection-hello versions
are unchanged. The source client identity changes with these scripts too.

`NetworkConfiguration.core_options` records the existing fx_api.rs rule:
Modern core explosions require particles, style 2, processor type at least 2
and screen shake together. Hitstop retains its explicit boolean. This function
returns a plan only and applies nothing to an active or prepared simulation.
It explicitly leaves combo_frame_ms at zero for Arcade, matching
EndlessSession.configure when no Endless run exists; applying the enabled
combos preference directly to Arcade would have changed existing behavior.

Dedicated Android specials are injected by TyrianSim.step from player-1 mask
bits 8/9, not a level-start setting. The later tick adapter must enforce their
negotiated use and original ownership, rather than invent a guest special or a
new simulation setting. This checkpoint does not change those input rules.

Verification: 20 cases pass across configuration, preparation, startup and real
ENet startup-connection suites, with no errors/failures/orphans and explicit
process exit 0. Tests cover each Modern prerequisite disabling the core option,
digest sensitivity, strict booleans, Arcade combo timing, old-version rejection
and the earlier readiness/mismatch barriers. New/changed GDScript lint/format
and whitespace checks pass. Complete-state serialization, process-history-free
level loading and shop/session integration remain pending. No game build was
handed over, and no device or Linux exported-package gate is claimed.

State-fingerprint implementation direction: retain the legacy replay snapshot
unchanged and add a separately versioned, read-only network serialization. Use
compiler-derived field traversal for the retained setup/current state/world,
so new fields cannot silently evade coverage. Encode primitive integers with a
fixed representation and hash in the bridge. Keep this private to identical
build identities and supported little-endian 64-bit targets; it is not a save
format or a cross-version protocol. Audit observer queues before enabling live
comparisons. No simulation rules or ticks are changed by serialization.

### Conservative diagnostic serialization with compiler field coverage

A new `Sim.network_diagnostic_bytes` traverses the retained LevelSetup, current
SimState, last input mask and entire World through derived field hashing.
Nested state/data types implement Hash so the compiler checks recursive field
coverage, including full RNG arrays/cursors, player and enemy internals, mode
and pending inputs, event scripts, effective tables, effects and carried state.
The legacy replay snapshot/hash implementation remains unchanged.

The collector has a domain/version prefix and a 16 MiB output cap. It is
restricted to little-endian 64-bit targets because Rust primitive slice hashing
may use native representation; pointer-sized scalars are written as eight-byte
little-endian values. Rust Hash traversal is not a stable cross-version format:
only identical source/compiler identities may compare these bytes. No claim of
cross-platform evidence follows from this implementation alone.

The bridge hashes this stream with SHA-256 through
`network_diagnostic_digest`; unloaded, replay/recording, unsupported-target or
oversized states return no digest. This is diagnostic only, not a save/restore
format or a gameplay-only live desync detector. The current world includes
observer/render/audio state, so comparisons require the same queue-consumption
boundary. Presented copies, keep_presented and replay-only bottom positions
are excluded; they do not control simulation rules. Bridge-global star/effects
history and startup loading still need their independent audited setup path.
No Loaded/Ready action has been wired to this diagnostic getter.

Three new Rust tests cover legacy omissions (devices, friction, enemy fire
waits, core effects and per-player pending mice), read-only/repeated traversal,
120 equivalent ticks with presented-state capture enabled on only one side,
fixed pointer encoding and collector bounds. All 39 formats tests pass. The
qualified full simulation run passes 158 cases with one existing ignored case,
excluding exactly the three previously reproduced Windows baseline failures
listed above. This is not an unfiltered green simulation suite or new C parity.

The rebuilt native bridge passes 11 Godot cases across diagnostic digest,
per-player mice, preparation and configuration suites, with no error lines,
failures or orphan nodes and explicit process exit 0. The getter rejects an
unloaded Sim, is repeatable/read-only, detects pending input that the legacy
hash omits, returns to its original value after clearing that override and
changes after a tick. Cargo formatting and changed GDScript lint/format pass.
Clippy passes with only the two previously documented baseline categories
allowed. No Android run, Linux package gate or gameplay/build handover occurred.

Next detached-load step: create a separate native preparation entry point using
the already validated configuration and session-owned mod API. Parse strict
native types/bounds again, construct the normal initial Arcade LevelSetup, and
use Sim::new plus the existing core-effect settings. Initialize rendering-only
stars with a private MT19937 at the original fresh-process seed 5489; do not
read/advance STARFIELD_MT or set PROCESSOR_TYPE/FX globals. Keep presentation
inactive until a later explicit handoff. Compare diagnostics before stepping or
consuming observer queues. This is a preview behind the original shop boundary,
not authorization to skip that shop or display a Ready action.

### Detached initial-level preview

`TyrianSim.prepare_network_level` now strictly reparses the 21-field initial
configuration, validates actual assets/equipment through the attached private
mod API, constructs the normal initial Arcade LevelSetup and uses Sim::new.
It applies the negotiated core effects and private rendering-only starfield
initialization, retaining presented-state capture. The core's usual initial
loop_top still runs as in ordinary loading; no subsequent step is performed.

The private star generator starts at the original fresh-process MT seed 5489.
`Sim.set_starfield` only replaces rendering stars and repeats their initial
advance; it does not modify gameplay RNG. The detached path neither reads nor
advances STARFIELD_MT and does not write PROCESSOR_TYPE or FX. It leaves FX
presentation inactive, so a later gameplay handoff still needs explicit effects
renderer initialization. Existing local load_level and setters remain intact.

`NetworkPreparation.prepare_preview` owns the detached node, rechecks content
before/after loading and captures its diagnostic before any tick/observer
consumption. Repeated preparation verifies the retained state instead of
reloading. Unexpected state changes fail and free the node. Clear, capture
failure and final context release also free it. The RefCounted PREDELETE hook
releases the node directly, since calling another script method during that
notification caused a runtime error in testing.

The original shop entry remains retained and unexecuted. This preview is not
permission to skip purchases/progression, mark the player session loaded,
show Ready or start gameplay. The next integration must negotiate the shop's
result and initialize presentation at a consistent boundary. The diagnostic
still includes observer state; no live gameplay-only desync claim is made.

Tests cover matching previews despite intervening local starfield history,
immutable repeated preparation, processor/loadout values, full-u64 seeds,
mandatory validation, refusal to replace an already loaded node, unexpected
stepping, explicit and automatic cleanup, and native rechecks of bad types,
unsupported devices, invalid seeds/money/levels/equipment and unknown fields.

Final verification: 16/16 Godot cases across preparation, diagnostic digest and
startup pass with no error lines/failures/orphans. A repeat on the same final
sources also passes 16/16 with explicit process exit 0. During development one
post-success teardown run returned a native access violation. The suite now
waits two process frames after releasing Music/Sfx streams; both final runs
exit cleanly. This does not establish the cause of that earlier native crash
or replace device/package validation. Cargo formatting, changed GDScript lint/
format and diff checks pass. Clippy passes with the same two documented
baseline categories allowed. No Android run, Linux exported-package gate or
build handover is claimed.

Next lifecycle step: bind the real startup connection to a session-owned
preparation context in a backend-only node. Both callers explicitly supply the
same selected episode before connecting. Propose through the real validator,
prepare a detached preview only after configuration agreement, and exchange its
actual diagnostic at the untouched pre-step boundary. Expose preview agreement
but no Ready/Start/game-scene action. Stop, failure and node exit must free the
preview and close the transport. The current player lobby remains unchanged;
episode discovery and the original shop's synchronized result still need their
own integration before this can become the player startup path.

The maintainer chose host operation of the original shop/menu while the guest
waits (2026-11-24). Source audit then clarified that two-player Arcade actually
uses MENU_2_PLAYER_ARCADE, the original Arcade Game Menu, not Full Game purchases.
Do not add a purchase flow to Arcade. Preserve Start Level, player-input rows,
Options and Quit with the necessary network ownership/safety adaptation.
The local Arcade Start action passes the last map destination to
campaign_leave_shop; the read-only initial-level resolver now follows that same
choice rather than the Full Game shop's default first destination. This is an
unused-preview correction, not a change to active gameplay or new C evidence.

### Real connection ownership and actual preview comparison

`network_preview_connection.gd` now owns the real startup connection and its
preparation context. Both callers explicitly supply the selected episode. It
proposes through the actual rule/asset validator and compares the actual
untouched preview diagnostics over reliable ENet after configuration agreement.
It exposes preview agreement, not Ready, Start or a gameplay scene action.
The coordinator's LOADED value is internal to this backend diagnostic barrier;
the player lobby is still the connection-only flow. No first-level/menu stage
is silently treated as completed by that name.

Invalid local preparation/proposals, mismatched or altered previews, transport
failure, cancellation and node exit clear the native preview and connection.
The wrapper checks health after synchronous state callbacks, so cancellation
cannot be returned as a successful proposal. Existing startup, menu and local
load code remains unchanged. Episode discovery/selection, the approved
host-operated original Arcade Game Menu and actual live handoff are next.
The guest will wait; no Full Game purchase screen is being added to Arcade.

Verification: 12 cases pass across real preview connections, existing real
startup connections and initial rules, with no errors/failures/orphans and
explicit process exit 0. Tests include real matching content/configuration/
preview agreement, retained original menu entry and unchanged Game state,
invalid-proposal cleanup, altered-preview cleanup, disconnect/exit and callback
cancellation. New/changed GDScript lint/format and whitespace checks pass.
No Android/device or Linux package gate was run and no game build was handed
over. These are two peers in one Godot process over real localhost ENet, not a
two-process, two-phone or internet gameplay test.

Host Arcade menu frontend checkpoint plan: reuse shop.gd's original picture-1
Arcade layout, menu engine, fonts, palette, navigation and Quit confirmation in
a small derived screen. Keep its state outside Game so no local campaign is
started or saved. Difficulty opens this one screen; Start records host intent
and returns to the existing live lobby (still explicitly connection-only).
Fixed input rows show the two phones and cannot cycle local devices. Options
is visibly disabled until its separate network screen is integrated/reviewed.
Do not open the Options child screen in this checkpoint. Android uses release
activation with drag cancellation. No gameplay or Ready action is enabled.

### Host-operated original Arcade Game Menu checkpoint

After the approved host-operated direction, Difficulty now opens
`network_arcade_menu.gd`, a derived original shop/Arcade screen. It reuses the
original picture-1 background, Game Menu title/rows, fonts, palette, menu-engine
layout and Quit confirmation. The small shared `_arcade_item_metadata` hook
returns empty metadata for every existing local menu; only this network screen
uses it to dim fixed player-input rows and unavailable Options. Keyboard/gamepad
navigation skips those unavailable choices. Desktop retains original mouse
selection/activation behavior; Android activates Start/Quit only on release and
cancels a dragged-off press. Phone labels are translated in all six locales.

This screen keeps its loadout, zero credits and selections outside Game. It
reads the selected episode's native script for the original shop song. Start
records a host request, retains the existing peer and returns to the live lobby,
which explicitly still says gameplay is unavailable. It does not launch a local
two-player level, perform a purchase, save a campaign or mark either player
Ready. Input rows cannot change local device assignments. Options/Help children
are not opened before this one-screen checkpoint is reviewed. Quit uses the
original Yes/No box; Yes closes the session. Unexpected scene exit also cleans
up. The guest stays in the connection lobby.

The source framebuffer capture is `build/network-host-arcade.png`. New tests
cover original menu identity, disabled rows, navigation, release-only Start,
peer preservation, unchanged Game episode/campaign/modes, cancelled touch,
fixed input rows and unexpected-exit cleanup. Existing Episode flow tests now
traverse the Arcade screen before returning to the lobby. Locale consistency,
glyph/width and hard-coded-text checks pass; changed GDScript lint/format and
diff whitespace pass. Existing shop/new_game formatter limitations are not
silently rewritten as part of this change.

Final frontend verification: 28 flow cases pass across the network Arcade,
Episode, existing Arcade mouse and local New Game suites. A focused follow-up
passes 10 cases across the final network Arcade tests and lobby suite (two
menu cases overlap the flow run). Both final processes exit 0 with no error
lines/failures/orphans. Quit Yes/No and all translated value/status widths are
also checked. An earlier 28-case process reported success then exited with the
previously observed Windows access violation; the successful repeat allowed the
final cleanup suite to complete. The cause is not established or claimed fixed.
The framebuffer capture exits cleanly too. No Android run, Linux exported gate
or game build handover occurred. Review this Arcade screen before its Options
child or a new frontend step; backend work can continue independently.

Next frontend plan, approved by the maintainer on 2026-11-24: retain the original
eight-row Options screen, with host-local Music/Sound volume and Done active.
Dim unsupported network save/load and local device configuration. Reuse its
original drawing, volume setters/bars, menu navigation and Android release
handling; keep remembered rows and status outside Game's campaign fields.
Done/Back returns to the same host Arcade menu/peer. Unexpected scene exit or
session loss cleans up rather than falling into a local campaign. Review only
this screen before any new Options child frontend. Audio preferences may be
saved locally; no campaign save/load or network configuration change is implied.

### Original host-local Options screen checkpoint

The approved eight-row direction is implemented by `network_options.gd`, derived
from the existing save_menu screen. It reuses original labels, picture-1 palette/
artwork, menu layout, volume bars/setters, keyboard/gamepad/mouse navigation and
Android release handling. Load/Save and Joystick/Keyboard/Mouse rows are dimmed;
Music, Sound and Done are active. Audio changes save the host's local preferences,
not a network campaign checkpoint or a guest setting.

Two small save_menu hooks supply the entry row and unavailable rows. Their
original defaults retain local campaign behavior; the network screen keeps its
remembered row and original zero-credit status in NetworkSession. It does not
consume the local save menu's static entry row or mutate Game's campaign/loadout/
menu fields. Arcade Options is now enabled; Done/Back restores its selected row
and the exact peer object. A fresh Episode/Difficulty flow resets menu rows.
Unexpected exit closes the session, and a lost host returns to a cleared lobby.
No save/load or controller child screen can be opened by this network screen.

Verification: 23 cases report success across existing Setup Options and touch
release suites, network Episode/Arcade and the three new Options tests. New
checks verify both Music and Sound values in active audio settings and the saved
setup.cfg, release-only volume changes, disabled rows, remembered selection,
unchanged local campaign fields/static entry row, peer preservation and cleanup.
The first run exits 0. A final run with added Sound persistence assertions has
clean assertion/error/orphan results but exits with the previously observed
Windows native access violation after the runner reports success. This is
qualified evidence, not a clean final process/package gate or a resolved crash.

The original-framebuffer capture `build/network-host-options.png` exits 0 and was
visually checked. Changed networking GDScript formatting/lint, locale consistency,
hard-coded-text and whitespace checks pass. No Android execution, exported Linux
package gate or game build handover is claimed. Options is the one frontend
screen awaiting maintainer review; playable co-op and Ready/live startup remain
pending. The selected original menu direction does not authorize replacing it
with a compact screen in a later continuation.

Next backend input step: add an explicitly Android touch/tilt-only input policy
and detached paired-tick runner. Existing touch and tilt reduce movement to mouse
deltas in -30..30; gamepad analog axes are outside this initial profile. Reject
out-of-range/malformed values, guest special flags and inconsistent dedicated
special bits instead of clamping remote inputs. Use the approved per-player
mouse API and OR the two new-key flags (the original flag means any key).

Capture hardware once per scheduled tick, retain the captured frame while
waiting/retransmitting, and require both next-tick inputs before one native
step. Preserve negotiated neutral delay prefill but capture that tick's future
local frame before advancing, so no future frame is skipped. Check the native
tick before and after each step; stop on external stepping or invalid inputs.
Use the existing bounded codec/buffer and do not create a new simulation clock,
predict inputs, mutate Game or enable a player scene/Ready action. A future
handoff must explicitly activate this runner only after real startup barriers.

Follow-up backend wiring: after the touch runner passes its native/reference
checks, add a separate gameplay backend derived from the preview owner. Bind
Ready and host Start explicitly to unchanged validated previews, then activate
the runner only after the startup coordinator reaches RUNNING. Multiplex binary
gameplay packets only in that phase and only for an opt-in listener. Keep all
existing connection-only screens and preview-only APIs unchanged. No automatic
clock or player scene handoff is added. Test actual ENet delivery and native
state equality, early-start rejection and failure/disconnect cleanup. This is a
backend simulation milestone, not a claim that phone gameplay is integrated.

Two-process verification step: add an explicitly invoked development probe,
not a player scene. Run host and guest in independent Godot processes over
localhost ENet, with explicit Ready/Start and one advance opportunity per normal
35 Hz physics tick. Record per-tick diagnostic hashes and compare both reports.
Warm up ordinary loading only in the host to perturb its process-global star
history. Reports, profiles and logs stay under ignored build/. Keep the detached
presentation/observer boundary untouched and verify actual process exits; this
still does not constitute Android, internet or player-scene gameplay evidence.

### Android-profile paired input runner

`network_touch_inputs.gd` explicitly scopes the initial runner to the approved
Android touch/tilt profile: devices [0,0], mouse deltas -30..30 and zero gamepad
analog fields. The generic codec still preserves i32 fields; this additional
policy rejects unsafe physical values before native calls. Player 2 cannot send
dedicated-special flags; player-1 special press requires its dedicated flag and
the negotiated dedicated-special option. Original linked-ship/action handling
remains in Rust. Existing local desktop/gamepad input paths are unchanged.

`network_touch_runner.gd` combines this policy, the existing bounded wire/buffer
and the native per-player mouse bridge. It captures a future local frame once,
retains it during stalls/retransmission and refuses to advance even neutral
prefill until that scheduled local capture exists. Each advance requires the
complete next pair and exactly the expected native tick. It applies both mice,
zero analog and the union of new-key flags, then calls the existing native step
once. Missing frames wait without prediction, neutral substitution or new
hardware sampling. Invalid physical data, conflicting duplicates, invalid
windows, external stepping or missing simulations stop the runner. Valid old
session/epoch packets are discarded before applying the current physical policy.
The caller owns the node; the session owner disposes it on stop/failure.

The runner has no clock, transport or player-scene side effects. Activation is
explicit and requires a fresh loaded native node. The 18 codec/buffer/runner
cases pass with a clean process exit. The five new cases include two detached
native peers under delay/reordering/duplication/delayed retransmission and an
independent direct-input native reference. All three match at every one of 180
ticks. This is input-delivery determinism evidence, not new independent C parity.

### Detached gameplay connection and independent-process probe

`network_gameplay_connection.gd` derives from the preview owner and adds explicit
Ready and host Start plus the touch runner. Unchanged content/preview checks
precede those commands; both Ready acknowledgements and the host's Start must
complete before activation. The startup adapter forwards bounded binary OT2N
packets only in RUNNING and only to an opt-in listener; connection-only and
preview-only screens retain their prior behavior. Gameplay failure/disconnect
stops the runner, closes the peer and releases the native node. Capture/advance
remain explicit; no new player simulation clock or scene handoff is introduced.

Eleven cases across real gameplay/startup connections and the runner report
success, including 60 matching native ticks over actual ENet, early/guest Start
rejection, duplicate Ready, malformed physical-input rejection and disconnect
cleanup. Five runner cases overlap the earlier 18-case selection. The process
then hits the known Windows native shutdown access violation; do not count its
internal success message as a clean process gate.

The source-only `tools/network_gameplay_probe.gd` runs independent host and guest
processes with explicit --probe-role/--probe-report arguments. Its driver offers
one advance per 35 Hz physics tick. Reports/logs/profiles stay under build/.
With two ordinary local-level warmups only on the host, both independent
processes execute 120 ticks at 35 Hz and produce identical configuration and all
120 per-tick diagnostic hashes. Neither reports a simulation/transport error.
The host process exits 0; the guest reports completion then exits with the same
native access violation. This confirms the shutdown issue also occurs outside
gdUnit; its cause is still unproven. A two-process simulation result is not a
clean two-process lifecycle/package gate, Android evidence or a complete level.

Diagnostics remain conservative and comparisons in these probes use untouched
observer-consumption boundaries. The backend has no active effects renderer or
phone HUD. Player-menu binding, role-specific live input/render/audio/pause,
level endings/progression, device checks and internet bootstrap remain pending.
The player-facing menu therefore still records preparation intent and does not
launch network gameplay. No build handover or Linux exported-package gate is
claimed; WSL remains unavailable. New/changed GDScript lint/format and whitespace
checks pass. No Rust gameplay or arithmetic implementation changed here.

Next player-flow integration plan: the maintainer chose a shared original-style
lobby Ready check, with episode/difficulty shown on both phones and host-only
Start after both Ready. First support adopting the persistent LAN node without
reparenting/recreating its live ENet peer. Keep its ownership with NetworkSession
and opt startup packet handling into that same connection. Adopt before allowing
normal polling of startup packets on a join, to avoid a protocol-listener race.

Initial compatibility still fingerprints all runtime bytes. On the first valid
configuration only, preparation may recapture the host's chosen episode with the
same copied mod selection. The new identity must equal the hello identity; after
acceptance the configuration stays immutable. This lets the guest wait while
host chooses an episode, without silently changing content or using stale tables.
No player scene is launched by adopting/recapturing a connection.

### Persistent transport adoption and shared lobby Ready checkpoint

The startup adapter can now adopt a fresh persistent LanLobby without
reparenting or recreating its peer. Its discarded default transport is freed;
the adopted node stays with NetworkSession, while stop closes the socket.
Preparation can recapture a later episode on the first configuration only,
using the same copied mod selection and requiring the full identity to remain
unchanged. Accepted configurations remain immutable. Twelve adoption/preparation
cases pass with process exit 0, including exact peer/parent preservation and a
guest initially captured for Episode 1 accepting a later Episode 3 proposal.

NetworkSession now binds the gameplay backend to its persistent menu transport
before host/join polling. The original host Episode/Difficulty/Arcade path is
retained. Arcade Start records intent; when a guest is compatible, the host
builds the initial configuration from the original loadouts/rules and selected
settings. Crypto-generated seed/session bytes do not draw from gameplay RNG.
Both sides validate the proposal, prepare matching native previews and expose
Ready only after comparison. Guest display receives the actual episode and
initial difficulty. Unaccepted host choices remain editable; once proposed,
they require session cancellation to change.

The chosen shared lobby design reuses the original picture-2 layout, fonts,
palette and touch-release behavior. Ready is explicit on each phone. Only the
host sees an enabled Start after both acknowledgements; guest Ready stays dimmed.
Cancel/Back releases the session. Status/compatibility/content errors and actions
are localized in six languages. Host setup captures effective mod preferences
without changing them. Original campaign fields are not used as session storage.

Start currently activates the detached backend at tick zero; it does not open
the player level, poll hardware or advance simulation. The screen explicitly
says the player view is pending/gameplay unavailable. This staged frontend
checkpoint is not a playable co-op claim. Role-specific live rendering/input/
audio, clock handoff, pause and progression remain next. Do not infer completed
player gameplay from the backend's RUNNING protocol phase.

Verification: 19 cases pass across the new shared lobby, existing lobby,
Episode, Arcade and Options suites, with no errors/failures/orphans and explicit
process exit 0. The new host/guest cases verify later episode synchronization,
locked proposal, release-only Ready, blocked early/guest Start, host Start,
unchanged local campaign fields, tick-zero backend activation and cancellation.
Translated normal/tiny-font widths are checked for all new labels/statuses.
Formatting/lint, strict locale consistency, glyph/width and hard-coded-text
checks and diff whitespace pass. The earlier Windows shutdown issue remains
unresolved despite this run exiting cleanly.

Real native-peer tests saved and visually verified the original-framebuffer
`build/network-lobby-ready.png`, `network-lobby-start.png` and
`network-lobby-guest.png` captures. They show the host Ready/Start states and the
guest's distinct episode and disabled Ready after acknowledgement. These are
source desktop captures, not Android phone validation or an exported build.
Review this one shared Ready screen before a new frontend step. The exported
Linux gate and two-phone/internet play have not run; no build was handed over.

### Approved player-view implementation plan

The maintainer approved the original full two-player HUD on both phones, with
each phone controlling its assigned ship. Keep the existing framebuffer,
playfield, fonts and dashboard; do not introduce an enlarged own-player HUD.
Implement this in the following order, preserving the existing local level path:

1. Separate level presentation initialization and post-step presentation from
   native simulation creation/stepping. The ordinary level calls the same
   operations in the same order. Add presentation accessors for level identity,
   title, loadout and processor type so a network view does not overwrite Game's
   local campaign fields to render another session.
2. Expose a borrowed simulation and assigned role only after backend RUNNING.
   The preparation owner remains responsible for freeing its unparented native
   node. A view must never add it as a child, reload it, seed it, fast-forward it
   or free it. Check the borrow before every presentation update. Disconnect
   must detach presentation before any further native method call.
3. Build and verify the shared player view first, without automatically leaving
   the lobby. Use the agreed configuration and freshly read campaign level name.
   Skip local achievements, recording, assists and local effect reconfiguration.
   Start audio locally without writing local volume into simulation state.
   HUD/audio/filter queues are observers and may be consumed only after startup
   comparison. Their consumption means the conservative diagnostic is no longer
   comparable to an untouched preview. Test tick-zero preservation, ownership,
   campaign isolation, both roles and original dashboard rendering.
4. Bind the view to a 35 Hz session clock only after its presentation checkpoint.
   Sample hardware only when a future frame is needed; preserve the frozen frame
   while waiting. Capture the assigned ship's touch/tilt delta with the existing
   movement helpers and existing action ownership. Route guest manual sidekick/
   rear-mode controls from player 2 state; never expose player 1's special to the
   guest. Advance through the backend only and present each executed tick once.
   Audit hitstop/slow-motion scheduling separately from simulation tick rules.
5. Add the explicit lobby-to-view handoff on both peers after Start, guarding
   against unequal scene-loading times and queued inputs. Escape, focus loss,
   transport loss and scene exit must stop or synchronize the session rather
   than opening an unsynchronized local pause/save flow. Specify the original
   pause-screen direction before implementing that separate frontend screen.
6. Verify real ENet peers with rendered views, independent process lifecycles,
   stalls, disconnects and both input roles. Then implement level endings and
   host-controlled Arcade progression through fresh epochs. Do not hand over a
   playable build before the exported-package gate and actual two-phone checks.
   Internet signaling/NAT traversal remains a later documented transport phase.

The first view checkpoint is deliberately detached from the player-menu clock:
it must establish safe reuse of the prepared simulation before live input,
pause, progression or an internet-play claim is introduced.

### Detached original two-player presentation checkpoint

`level.gd` now shares presentation initialization and post-step observation
without creating a second simulation path. Ordinary local loading/stepping keeps
its operations and order. Presentation accessors let `network_level.gd` use the
negotiated level, title and loadout without changing local Game campaign fields.
The network view binds once, only to a running tick-zero backend. It borrows the
unparented prepared node; disposing the view does not dispose that node. Backend
stop detaches/hides the view, and backend tree exit also clears its references.

Both roles reuse HudRenderer and picture 6, including both players' status bars
and the original level name. Local achievements, recording, assists, effect
reconfiguration, direct stepping, fast-forward, hardware polling and automatic
physics processing are disabled in this detached view. Local audio volume is
applied to output without writing it into the simulation. A successful backend
tick may be presented exactly once; repeated or skipped tick presentation is
rejected. Observer consumption starts only after startup comparison.

Twenty cases across gameplay connections, local level entry and Android touch
weapons pass with zero errors/failures/orphans and actual process exit 0. New
coverage verifies both roles at tick zero, unchanged local campaign fields,
disabled direct stepping/clock, single binding, ownership and disconnect cleanup.
Two real ENet peers also match conservative diagnostic hashes after each of 12
backend ticks with the same HUD/audio/filter observation boundary. The unchanged
60-tick ENet case continues to pass. This is same-build rewrite evidence, not
independent C parity or two-phone testing. The earlier intermittent Windows
shutdown issue remains unresolved; this run exited cleanly.

Both original dashboard images were saved under build/network-hud-1.png and
build/network-hud-2.png, inspected and have identical SHA-256 hashes. These are
dashboard framebuffer captures with a black playfield, not live phone captures.
GDScript format/lint and diff whitespace checks pass. The view is not selected
by the player lobby: live clock, assigned touch controls, synchronized entry,
pause, progression and internet transport remain pending. Review this detached
original-HUD checkpoint before the clock/input handoff. No APK or exported build
was handed over and the unavailable WSL/Linux package gate was not run.

### Assigned touch-input checkpoint plan

After approving the detached HUD checkpoint, the maintainer requested commit,
push and continuation. Keep the chosen original full HUD and reuse the existing
TouchFlight, TiltFlight and TouchWeapons implementations. Add an explicit
Android-only input enable to the detached network view; do not enable input or a
clock merely by binding/rendering the view. Feed only real screen touch/drag
events, with weapon-finger ownership before flight-finger ownership, as locally.

Project the existing HUD state into the assigned phone's controls only: the
native HUD already describes player 2's sidekicks/rear mode in two-player play.
Hide those controls for player 1; hide Special for player 2 and when the agreed
dedicated-special option is off. Do not change the full dashboard itself or the
local TouchWeapons path. Steer relative to native player index role-minus-one,
using the existing destination/tilt calculations without new acceleration,
prediction, analog or mouse conversion. Normal fire remains held flight touch.

Capture only when the backend requests a new future input. While stalled, keep
the transmitted frame frozen and retain later touch/button events for the next
capture. Presentation alone must not consume a queued button press. Reset fingers
and pending actions on input disable, disconnect and focus loss; an active input
session losing focus closes rather than opening a local unsynchronized pause.
Test both roles against the existing helpers, delayed capture, button ownership,
tilt, cancellation, invalid lifecycle calls and real native ENet delivery.

Clock audit finding: local boss slow motion comes from thread-local FxRender,
read by Level._fx_tick and Effects.consume_tick. The prepared network simulation
deliberately leaves fx_on false to preserve isolation; enabling the current
global effects path would mix sessions and depend on prior local play. Therefore
do not connect a live clock using that global path. Finish assigned input first;
then isolate/audit session effects and negotiated speed pacing before enabling
the player-menu clock, synchronized entry and pause. No gameplay mechanics change
or presumed equivalence of a replacement timing path is authorized by this plan.

### Assigned touch-input checkpoint results and next timing decision

`network_level.gd` now exposes explicit enable/disable/capture calls for Android
touch. Binding a view still does not enable input or physics. Screen touch/drag
uses the existing flight and weapon-finger helpers. Captures use native player
index role-minus-one and the existing touch/tilt movement calculations; analog
and new-key stay neutral, and normal fire requires a held flight finger. The
view does not read desktop/gamepad bindings or the global auto-fire preference.

`network_touch_inputs.gd` projects the existing HUD into role-specific controls
without modifying the dashboard or native state: player 1 receives Special only
when negotiated; player 2 receives the existing sidekick/rear-mode controls.
Presentation does not consume their queued releases. Capture checks the backend's
need before reading sensors or consuming an action, preserving frozen future
frames and later pending gestures through stalls. Disable/disconnect clears
fingers, pending buttons and tilt calibration. Focus loss while input is enabled
also stops the backend, without entering the local pause/save flow.

Seven focused input cases pass, including comparisons against existing flight
and tilt helpers, per-role control ownership, release-only actions, queued
actions during stalls, explicit Android enable, cancellation, disconnect and
focus loss. Another 29 cases pass across actual gameplay connections, runner,
TouchWeapons, local Android level controls and the native mice bridge. Both
processes exit 0 with zero errors/failures/orphans. The rendered real-ENet case
now samples each view's held touch through capture_network_input and matches
diagnostics after every one of 12 backend-driven ticks. The independent direct
runner/reference and 60-tick ENet cases also pass. Format/lint and whitespace
checks pass. No new phone, package, internet, boss-pacing or C parity claim is
made. The player lobby still does not enable this view or a live clock.

Next proposed timing work (requires express mechanics approval before coding):
give each network simulation its own existing FxRender instance, initialized
from the agreed settings/seed after startup comparison, without rewriting core
FX configuration or RNG. Route its rendering/event consumption and slow-motion
readout to that instance; leave the ordinary local global path intact. Reuse the
existing FxRender frame/update logic and the existing credit-based pacing rule,
using negotiated game speed rather than a phone-local speed/override. Tests must
compare the isolated path with the existing local path for boss events and
slow-motion recovery, demonstrate that interleaved peers and prior local play
cannot change it, and verify no changes to core state/RNG beyond the existing
observer queue consumption. Only then connect a clock and synchronized entry.

Remaining uncertainty: effects state currently owns the boss slowdown ramp and
is shared across simulations. Moving that ownership may affect the real-time
spacing of gameplay ticks if event consumption, frame order or recovery credits
change. The existing detached tests do not cover a defeated boss with a live
clock; the absent c-final reference checkout prevents new independent C timing
evidence here. This falls under AGENTS.md's requirement for express approval of
an uncertain mechanics-affecting adaptation. The proposal preserves the current
algorithms; it does not authorize omitting boss slowdown or changing movement,
damage, collision, balance or gameplay RNG rules.

The maintainer expressly approved scoped effect isolation and pacing adaptation.
Implementation will select an owned renderer only within a network native call,
restoring the previous renderer selection on return (including nested calls and
unwinding). Existing rendering helpers keep their algorithms and local default
renderer; a scoped selector also covers their deeper compositing helpers.
Preparation stores validated presentation settings without activating effects.
An explicit tick-zero presentation start after RUNNING creates the owned
renderer without changing the core diagnostic. Each subsequent native step
consumes FX events into that renderer using the existing frame function/order.
Verify owned/global equivalence through a boss event and full recovery before
adding a clock. Network pacing will keep its own fractional credit, never use
Effects' shared credit or the phone's local bullet-time shortcuts. Normal speed
remains 35 ticks/s; other negotiated original speed presets change calling pace,
not the contents of a simulation step. The hidden display-rate-dependent speed
must remain unavailable to the live network clock until its rate is negotiated.

### Scoped effects and explicit network clock checkpoint

The native preview stores validated presentation settings without activating
effects. `start_network_presentation` initializes an owned renderer only at tick
zero; repeated starts there are idempotent and leave the conservative core
diagnostic unchanged. The network view calls it after RUNNING, before display
initialization. Each native step then uses the existing FX event/frame function
with the existing presented-iteration/time boundaries. No core FX settings,
processor/starfield globals, movement or gameplay RNG are reset by activation.

`FxScope` selects an owned renderer for native instance effects/render calls,
including their deeper compositing helpers, and restores the previous selection
on return, nested calls and panic unwind. Ordinary local loading clears the
network presentation state and retains its default renderer and algorithms.
Damage-number/rumble options remain off in the network renderer because they
are not part of this initial negotiated configuration; no unnegotiated local
options change its effects. Pending FX events remain presentation state, outside
the core diagnostic, and are not a network desync detector.

`network_tick_clock.gd` copies the existing fractional-credit pacing rule with
session-owned credit. The network view requires explicit input and clock enable;
the clock can start once at tick zero and only when physics callbacks use the
negotiated preset rate (14/23/28/35/49 ticks/s). The owner must select that rate;
the detached view never changes global physics settings or honors local CLI
speed overrides. Hidden refresh-dependent speed 6 cannot enable this clock.
Boss slowdown comes from the owned native renderer, without using shared
Effects credit or phone-local bullet-time shortcuts.

A due tick remains due while inputs are missing. Hardware is sampled once for
the future frame; later gestures remain pending and no catch-up credit builds
during a stall. A complete pair advances through the backend once and presents
once. Focus loss/disconnect clears input and clock. An ended level or changed
physics rate disables input/clock, without invoking local campaign progression.
This is an explicit prototype driver, not a lobby-to-player handoff or a pause
protocol. Rendering filters and other presentation globals still need a separate
ownership audit before claiming independent rendered sessions in one process.

Verification on Windows: all 62 active Rust bridge tests pass (3 existing
ignored), including original image-reference cases. New Rust cases compare the
owned/default renderer through a boss event and full recovery with another
renderer interleaved; they also test nested selection/unwind and unchanged core
diagnostic bytes. Three Godot clock cases verify negotiated speed selection and
credit equivalence with the existing Effects rule. Forty Godot network/control
cases report zero errors/failures/orphans, including two real ENet views running
their own physics clocks: one stalls at neutral prefill, preserves its frozen
frame while a finger releases, then resumes with all 24 diagnostic hashes
matching. The process subsequently exits with the previously observed Windows
access violation (-1073741819); this is not a clean lifecycle gate. Another 22
local effects/bullet-time/entry cases pass with an actual clean exit 0.

Rust/GDScript format and GDScript lint pass. Clippy passes with the two previously
documented baseline allowances (`needless_range_loop`,
`mem_replace_with_default`); an unfiltered clean lint is not claimed. The rebuilt
Windows native library is internal test output. No APK/build was handed over,
no two-phone or internet tests ran, and the unavailable WSL exported-package
gate remains unrun. Next: guarded player-menu handoff, entry/exit ownership and
pause/progression, then independent-process/device/internet verification.

### Player-menu handoff implementation plan

The maintainer approved the input/effects/clock checkpoint and requested commit,
push and continuation. Reuse the approved full two-player player view and the
original entry fade. Do not create a new pause/menu design in this step.

1. Add an optional pre-tree scene preparation callable to the existing scene
   replacement path. Rejected preparation frees the new node and preserves the
   old screen. Default callers retain their existing behavior. Bind the session's
   borrowed native node before the player scene enters the tree.
2. Defer the RUNNING-to-player handoff from NetworkSession, checking the expected
   backend identity and current lobby to reject stale callbacks. Mark that lobby
   as handing off so its exit does not close the persistent transport. The owner
   selects the negotiated physics rate and restores the prior rate on all exits.
   Android owns the initial supported input profile; desktop tests may inject a
   platform-name callable, without adding a shipped desktop control profile.
3. Finish the original local entry fade without simulation/input capture, then
   exchange bounded binary READY messages for the current session/epoch/role and
   immutable configuration digest. Only after both views report ready may the
   production player scene enable its clock. Reuse the existing wire READY kind;
   reject malformed/conflicting current messages, discard valid old contexts and
   make duplicates idempotent. Detached backend/clock probes remain explicit.
4. The player scene owns presentation only. Back/Escape and focus loss close the
   prototype session, then return to the existing lobby. Disconnect and first
   level end do the same; do not write saves, abandon a local campaign, open a
   local pause, select the next level or claim synchronized pause/progression.
   Unexpected scene replacement must also release the session. Restore clock
   settings and detach borrowed references before further drawing/stepping.
5. Test host and guest player-menu handoffs with real ENet, delayed view readiness,
   cancellation/stale callbacks, original fade holding tick zero, platform/rate
   gating, input delivery and exit cleanup. Preserve local Game fields and prior
   scene behavior. Update lobby wording to describe a first-level LAN prototype,
   with translated original-font text and no internet or device-validation claim.

This step does not hand over an APK/package. Pause design, later levels,
independent-process shutdown, two-phone checks and internet bootstrap remain
required work in the complete plan.

### First-level player-menu handoff checkpoint

NetworkSession defers handoff only for its expected running backend and current
lobby. The optional scene-preparation callable binds the borrowed native node
before tree entry; rejection preserves the old screen and frees the new node.
Ordinary scene callers keep the default path. The existing lobby marks its exit
as handoff so its transport survives. The owner selects the agreed clock rate
and restores the previous rate on session exit, including unexpected scene
replacement. Production handoff requires Android; a platform-name callable
allows source tests to exercise that route without claiming device validation.

`network_player.gd` reuses the full two-player view, original entry fade and
touch helpers. Once its fade finishes, it sends a binary READY with the current
session/epoch/role, tick zero, control sequence 1 and immutable configuration
digest. Both views must acknowledge before the production scene enables its
clock. This barrier is distinct from the human lobby Ready check. It uses the
existing bounded wire grammar and reliable transport. Duplicate readiness is
idempotent, valid old contexts are discarded, and malformed/current conflicting
readiness closes the session. Detached backend/clock tools retain explicit APIs.

Back/Escape, focus loss, transport failure and first-level end close this
prototype session and return to the existing lobby. No local pause/save flow,
campaign abandonment, achievements or next-level transition is invoked. The
owner retains a diagnostic exit code; stale deferred callbacks cannot reopen a
cancelled session. Normal desktop local play and its scene replacement calls
keep their previous defaults. The six translated lobby footers now describe a
first-level LAN test rather than saying gameplay is unavailable.

Fourteen cases pass across player-menu handoff, existing gameplay connections
and scene-load failure handling, with zero logged errors/failures/orphans and
actual process exit 0. Host and guest source flows use an injected Android check,
hold tick zero through fade/remote-view delay, preserve local Game fields,
deliver held-touch input over real ENet and match all 60 per-tick diagnostics.
The guest case uses negotiated Turbo despite different local settings, and both
exits restore the previous physics rate. Back and focus loss return to the lobby
and release the peer; stale handoff and rejected-scene preparation are covered.
The barrier test covers both roles, duplicates, old context and a conflicting
digest. Natural level completion and synchronized progression were not tested.

Another 26 cases across lobby/Episode/Arcade/Options, touch projection and pacing
report zero errors/failures/orphans, followed by the previously observed Windows
shutdown access violation (-1073741819). Do not count that run as a clean process
gate. The clean handoff run does not resolve this intermittent lifecycle issue.
GDScript format/lint, strict six-language key/format checks, glyph/width checks,
new lobby text widths and whitespace checks pass.

The release native library also cross-compiles successfully for
aarch64-linux-android with the documented NDK and explicit 16 KiB ELF flags;
llvm-readelf reports 0x4000 alignment on every LOAD segment. This is internal
compile/alignment evidence, not an APK, a two-phone run or an exported-package
gate. The native Windows code was unchanged in this handoff checkpoint.
Source dashboard/playfield captures at tick 60 were saved and inspected as
build/network-player-1.png (Episode 3) and build/network-player-2.png (Episode 4).
They are framebuffer composites, not screenshots from phones. No APK/build was
handed over and the unavailable WSL/Linux package gate was not run.

Next required steps remain synchronized pause/exit design, original level-end
statistics and host-controlled Arcade progression through new epochs,
independent-process shutdown, two-phone execution and internet bootstrap.

### Approved synchronized-pause implementation plan and input audit

The maintainer chose the host-operated original Pause menu while the guest sees
the original paused display. Either phone may request pause; only the host may
resume. Host Quit uses the original confirmation; the guest may leave with Back.
Keep the original nine-row Android layout. Music/Sound, Return and Quit work;
negotiated detail/speed and unsupported Help/More/Controls remain visibly locked.
Volume changes stay host-local and must not reapply gameplay settings.

The local pause path resets TouchFlight/TouchWeapons and mouse/new-key capture,
but does not reset the simulation, tilt neutral/filter or pacing credit. Android
ordinary ticks also keep player 1's dedicated-special flag set: player.rs uses
Some(false) to suppress legacy special gestures. Generic zero-mask input would
lose that flag. Preserve it in post-pause neutral frames, with no movement,
fire, analog, new-key or special press. This is the existing Android control
contract, not permission to introduce a new special-activation rule.

Implement and verify in this order:

1. Extend the pure input buffer to configure an absolute start tick, retaining
   the existing zero-start API/default behavior. Add an input-only runner resume
   at the same native tick under the next epoch, discarding unexecuted old
   frames and prefilling the existing delay with profile-correct neutral input.
   Never reload/reseed/reconfigure the native node. Verify unchanged complete
   native diagnostics during buffer reset and equivalence to the existing
   cleared Android input path after resume, including an equipped special.
2. Add a transport-independent pause state machine. On a host pause request,
   commit target tick current-host-tick + input-delay + 1. Reliable ordered ENet
   sends that commit before later host input frames; a peer can reach the target
   but cannot execute beyond it before receiving the commit. A guest request
   asks the host to choose the target. Quiesce new input captures while arming;
   retain already transmitted frames unchanged until the target is reached.
3. Freeze before the target's next simulation step. Exchange bounded STATE
   digests at that exact post-presentation boundary; both must match before the
   host menu opens. Keep the core/RNG/effects tick progression stopped during
   pause. Host resume commits a new input epoch at the same native tick, then
   both reset only their input buffers and exchange new-epoch READY digests.
   No simulation step may resume before both acknowledgements. Old-epoch input
   is discarded; malformed/conflicting/current out-of-order controls fail closed.
   Use bounded control sequence/history and preparation/resume timeouts, with
   no timeout while humans are deliberately paused. Keep all traffic on the
   existing reliable ordered channel; unordered/multiple-channel transport would
   need another ordering audit before reusing this target-tick proof.
4. Integrate the backend's advancement/capture gates and clock without resetting
   the existing due-tick/credit or tilt calibration. Clear held fingers and
   queued buttons at pause/resume, and require fresh flight touch afterward.
   Show the guest's existing PAUSED text; reuse the original frozen host Pause
   menu with locked rows and narrow audio setters. Reuse the original touch
   pause symbol and release hit area; keep local menus/input unchanged.
5. Test pure/adverse control delivery, duplicate/stale/conflicting messages,
   boundary hashes and repeated epochs; native input resume/reference equality;
   real ENet host/guest pause and resume, queued fire/movement, menu audio,
   locked settings, Back/Quit, disconnects and unchanged local campaign fields.
   Save original-framebuffer host/guest pause captures and verify locales and
   formatting. Record actual native process exit codes separately from assertion
   results. No APK handover or internet/device validation is implied.

### Synchronized-pause implementation and evidence (2026-11-25)

The approved screen is implemented in `network_pause_menu.gd`, deriving the
existing Pause menu. The original nine rows, volume bars, quit confirmation,
selection sounds and release-based touch targets remain. Disabled negotiated
detail/speed values use an optional unavailable-row drawing callback in
MenuEngine; ordinary menus retain their existing disabled rendering. Volume
actions use narrow output setters, avoiding broad Setup application to the
simulation or negotiated physics rate. No locale strings were added.

`network_pause.gd` owns bounded controls, exact boundary STATE comparison and
new-input-epoch READY acknowledgements. The backend gates capture/advancement;
the player scene owns the frozen host menu/guest PAUSED display. Resume resets
only the input buffer at the absolute native tick, preserving the borrowed node,
RNG, effect state, tilt calibration and fractional clock credit. Profile-neutral
prefill preserves player 1's dedicated-special flag. This boundary diagnostic
includes observer queues; it is not a general live desync detector or snapshot.

Validation on Windows source:

- Combined pause/input/handoff run: 23 cases passed, process exit 0. After the
  game-over Back guard was added, the three-case real ENet pause-flow suite
  passed again with process exit 0 (two cases overlap that combined run).
- The native runner reference covers 100 ticks with an equipped special,
  resuming at tick 60 on the same node. Complete diagnostics match the existing
  cleared Android input path at every tick; stale input is discarded.
- Real ENet exercises requests from both roles, repeated epochs, original touch
  pause release, frozen ticks/digests, locked rows, local audio, retained clock
  credit/tilt calibration, guest Back and host confirmed Quit.
- Gameplay/view/clock/entry/weapon regression assertions passed all 32 cases,
  followed by the previously observed native shutdown access violation
  (-1073741819). A passing assertion summary is not a clean process exit.
- Original touch Pause alone passed 16 cases with process exit 0 using both
  the committed renderer and the current renderer in separate fresh profiles.
  An earlier combined local Pause run failed the quick-load modal's fixed-frame
  waits; this was not reproduced in either isolated comparison. No test waits
  were changed to hide that result. The full three-suite local Pause retry then
  passed all 30 cases with process exit 0 in another fresh profile. The earlier
  timing failure remains recorded rather than classified as a proven baseline.
- All 14 changed/new GDScript files pass formatter and linter checks;
  `git diff --check` passes. Host and guest framebuffer captures were inspected
  at `build/network-pause-host.png` and `build/network-pause-guest.png`.

This checkpoint supersedes the earlier prototype Back-to-lobby behavior during
active play: Back now requests Pause; guest Back while paused leaves. Focus loss,
disconnect and first-level completion still close the session. Original level-end
statistics/progression, independent-process shutdown, two-phone execution and
internet bootstrap remain next. No APK/package was handed over; the unavailable
WSL/Linux exported-package gate was not run.

### Progression audit and detached Statistics checkpoint (2026-11-25)

The remaining-work checklist and ordered level-completion plan above were
documented before implementation. The maintainer selected the original
two-player debrief/Statistics on both phones, with host-only advance and the
guest waiting. The already approved host-operated Arcade menu follows later;
this checkpoint changes no live level handoff or Arcade menu.

The local path is `level.gd::_finished_level_stats` and
`Game.campaign_level_finished`: it preserves carry and player-2 cash, tests
any-player survival separately from all-player survival, applies collected warp
routes, adjusts difficulty and retains earned loadout before debrief. Afterward
`campaign_after_debrief` runs the campaign script, whose shop/story/bonus/episode
branches cannot be replaced with a level-file increment. Normal all-dead endings
use the existing retry path instead of the successful debrief.

Native loading is currently intentionally initial-only: `network_load.rs`
requires zero cash and difficulty = initial + 1; `network_initial_configuration`
requires the initial equipment and first destination. Local `load_level` instead
accepts campaign initial difficulty, `LevelCarry`, mode/cash setup and bonus
status. The existing seven-value bridge carry includes both players' friction,
held special fire and player-2 sidekick level/series. Adapting this setup for
later detached network levels could affect mechanics if ordering or field
coverage differs. Express approval was requested under AGENTS.md before that
adaptation; equivalence is not assumed. No native loader or simulation mechanics
have been changed in this checkpoint.

Implemented safe preparation:

- `network_level_result.gd` captures a copied final result only for an ended
  simulation at the caller's fully presented tick. It retains both loadouts,
  exact signed 64-bit cash representations, original carry and route/survival
  flags. Reads are bracketed by unchanged native diagnostics. Canonical local
  hashing sorts dictionary keys and uses tagged, length-prefixed values with
  exact integer bits and bounded sizes. No remote Variant decoding is added.
- `debrief.gd` now has explicit data, mode, elapsed-time, background, wait and
  completion hooks. Defaults retain the original local campaign/Endless paths.
  `network_debrief.gd` reuses that renderer with copied session inputs, original
  two-player cash rows, animations, Statistics artwork and touch footer. Only
  host input emits advancement requests; an external coordinator must commit
  each phase after both screens are ready. Future phase commits are rejected;
  duplicate commits are idempotent. The guest uses the existing localized
  host-wait text in the original footer position. No new strings were added.
- The owner may freeze the final frame with the original frozen-level renderer
  without assigning `Game.debrief_frozen`. Detached previews use the existing
  black fallback for the summary; the detailed Statistics uses original pic 2.
  Elapsed seconds are an explicit presentation input; agreement on the host's
  measured value still belongs in the future coordinator, not simulation ticks.

These are detached components, not playable multi-level support. The current
network player still closes on level end. Result/control agreement, live scene
handoff, session-owned campaign cursor, retry/ending routes, next-level native
preparation and new epoch/load/view barriers remain to be implemented and tested.
Do not interpret directly committed view phases in unit tests as wire agreement.

Validation: the combined Windows source run passed 20 cases across six suites
with actual process exit 0: seven new result/view cases and 13 existing local
debrief/Statistics/touch/exit regressions. This covers natural native completion
and repeated read-only capture, copied two-player results, exact 64-bit values,
route/carry preservation, canonical hashing, host-only requests, release-based
footer input, duplicate/future phase commits and unchanged local campaign fields.
The guest footer fits both original font sizes in all six languages. The frozen
live-level handoff is not yet tested; the inspected captures
`build/network-statistics-1.png` and `build/network-statistics-2.png` show detached
Statistics with fixture values. All five changed/new GDScript files pass formatter
and linter checks, and `git diff --check` passes. No new APK/package or Linux gate
is claimed.

### Completion agreement implementation plan (2026-11-25)

Next implement and test result agreement and screen-phase controls independently
of later-level loading. Extend the fixed OT2N codec with distinct LEVEL_RESULT,
LEVEL_READY and LEVEL_ADVANCE kinds, leaving existing input/pause fixtures intact.
RESULT adds a four-byte elapsed-seconds field (72 bytes total); the other two
retain the 68-byte digest payload and use sequence 1/2 for summary/Statistics.
Only the host sends ADVANCE. RESULT sequence is zero, tick is positive, guest
elapsed is zero and all values/lengths/roles remain strict. Existing source
identity checks reject clients lacking this additive protocol extension.

Use a pure per-level coordinator bound to session, active input epoch and role.
Each peer captures its own final fully presented result and compares the same
tick/digest; the host supplies presentation-only elapsed seconds. Permit one
bounded early remote result while the other peer finishes the outstanding input
ticks. Continue only those ticks, then stop; disagreement or a ten-second
agreement timeout fails closed. No result payload is deserialized from the peer.
For each of two original screens, both announce readiness, the host requests
advance and only a host commit releases the phase. Preserve an early host request
until the guest is ready. Duplicates are idempotent; conflicting digests, skipped
phases and guest commits fail. No human-wait timeout applies after agreement.

Wire explicit backend APIs and ENet dispatch/gates to this coordinator, keeping
pause controls separate and respecting pause's current input epoch. Do not
activate a partially wired player-menu transition: the current live player still
closes on level end until final-frame/debrief ownership and continuation policy
are integrated together. Test pure adverse delivery, exact codec fixtures and
real ENet result/phase agreement, including a naturally ended native pair and a
pair that resumed into a new input epoch. No native loader change is authorized
by this plan; its existing scoped mechanics approval remains pending.

### Completion coordinator checkpoint (2026-11-25)

Implemented the additive fixed-size kinds and `network_completion.gd` pure
coordinator. Existing INPUT/STATE/READY/START/PAUSE/LEAVE fixtures retain their
version, sizes and semantics. LEVEL_RESULT is 72 bytes with an exact digest and
host-only elapsed-seconds value; LEVEL_READY/LEVEL_ADVANCE are 68 bytes with
summary/Statistics phases 1/2. The guest cannot send a commit or nonzero elapsed
time. Result comparison covers the canonical record's configuration, final tick,
complete native diagnostic and copied two-player results, without decoding peer
result objects. Valid stale epochs are discarded; future epochs fail.

The backend exposes explicit final-result capture, agreed snapshots/elapsed time,
screen readiness and host advancement. It freezes native advancement at the
local final boundary, or at the early remote result's bounded target while the
other peer catches up. Completion uses pause's current input epoch rather than
startup's original epoch. A natural end supersedes a pending later pause target;
agreement/host-request preparation has a ten-second timeout, while deliberate
human waits after agreement have none. Disconnect/failure clears the owned
result/coordinator and invalidates borrowed views. No simulation setters, native
loading, campaign globals or local save writes are introduced.

The final completion/codec/ENet run passed all 13 cases with actual process exit
0. It includes unchanged original packet fixtures, strict new packet fixtures,
bounded early results, stale/future contexts, duplicate/conflicting controls,
phase ordering, host-only commits and timeouts. Real ENet peers stepped and
presented native ticks through ordinary game over, acknowledged it through the
normal delayed new-key input, and compared final results. One peer was held a
tick behind to verify receiving an early result still permits that final tick.
The same run verified a prior pause/resume moved completion to epoch 2, preserved
final diagnostics through both phase commits, rejected a different level-name
record and cleaned up on disconnect. The initial ENet harness omitted the
original game-over key acknowledgement and timed out; adding that scripted input
resolved it without changing game rules or forcing level end.

The separate gameplay/Pause/debrief/result regression run passed all 20 cases
with actual process exit 0. Together the two final runs cover 33 cases without
errors, failures or orphans. All five changed/new GDScript files pass formatter
and linter checks; `git diff --check` passes. Clean exits in these runs do not
establish that the previously intermittent Windows native shutdown crash is fixed.

These are backend tests. The live player still closes on first-level end; it does
not yet open debrief/Statistics or advance a campaign. The terminal game-over
fixture exercises phase controls directly and does not authorize showing a
successful debrief after death. The final-frame handoff, survivor/retry routing
and host Arcade continuation remain next, with later-level loading still subject
to the pending scoped approval. No new frontend direction, APK/package handover,
physical-device test or exported Linux gate is claimed. The preceding
result/Statistics checkpoint was pushed as `b5e639b`.

### Live first-level Statistics handoff plan (2026-11-25)

Reuse the approved original shared Statistics flow inside the existing owned
player scene. On the final fully presented tick, stop the clock, clear flight
gestures and capture the result once; retain the borrowed native node until the
owner closes the session. Measure host-only wall time from the view-start barrier,
including human pauses, without assigning Game.level_start_ms or changing ticks.
Await matching results before routing: any surviving player opens the original
two-player debrief/Statistics; normal all-dead results retain the prototype exit
without showing a successful debrief. Current initial Arcade validation remains
unchanged; bonus/retry campaign routing belongs to the later cursor adaptation.

Bind and freeze the original final framebuffer before adding the debrief child,
then connect readiness/host requests/commits to the completion backend. Clear
gameplay input and hide its pause target while the original screen owns input.
Preserve focus-loss/disconnect cleanup while the native node remains borrowed.
Freeze/drawing and every screen transition must leave final native diagnostics
unchanged. Handle reentrant backend notifications and failed bindings safely.

Extend the existing completion READY/ADVANCE sequence range to phase 3 for an
internal fade-finished barrier. The view itself retains only its two user-facing
screens. Each peer announces phase 3 only after its original final fade; the host
automatically requests the commit. This prevents session teardown from cutting
off the other phone's fade. For this explicitly first-level LAN prototype, both
then return to the existing lobby. This intermediate exit does not implement or
replace the approved later host Arcade continuation, retry or next-level load.

Test the live controller's result gating, frozen background, both original
screens, host-only input, phase-3 wait, all-dead exit, focus loss/disconnect and
native ownership. Use named fixture results for controlled successful-screen
tests and distinguish them from natural native completion evidence. Re-run the
real ENet completion and existing player/Pause/debrief regressions. No simulation
or later-level loader change, new frontend layout or APK handover is included.

### Live first-level Statistics implementation (2026-11-25)

`network_player.gd` now routes its final fully presented tick through result
agreement instead of immediately closing. It captures once, stops the clock,
clears gestures and retains focus-loss/disconnect handling. The host's private
wall-clock start is recorded at the view-ready barrier; no local campaign timer
or simulation timing is assigned. After agreement, a surviving result binds the
original `network_debrief.gd` as an owned child over the frozen final playfield
and full two-player HUD. The borrowed simulation remains owned by preparation.
The agreed core diagnostic must still match before binding and remain unchanged
by framebuffer freezing. Failed binding/changed state closes safely.

Readiness and host requests now drive the two original screen phases through
the completion backend. READY/ADVANCE phase 3 is the internal final-fade barrier:
both views finish fading before the host commits prototype exit. Phase 3 has no
additional menu or input prompt. The host and guest then return to the existing
lobby; this remains a first-level test, with the approved later host Arcade menu
and campaign continuation still pending the loader/cursor work. All-dead normal
results do not show successful Statistics or invent a retry policy.

Cancellation also guards the original debrief's deferred entry and post-wait
continuations. The network view's original palette-fade loop stops when removed,
so an old disconnected screen cannot fade the replacement lobby. Ordinary local
debrief rendering and navigation remain on their existing default paths.

Validation ledger:

- The initial combined controller/completion/ENet/codec run passed 17 cases with
  process exit 0, including the new fade phase. A separate player-menu/Pause/
  detached-result regression run passed 14 cases with process exit 0.
- After cancellation guards, the controller/debrief/local-regression run passed
  22 cases with process exit 0: five live-controller cases, four detached-view
  cases and all 13 original local debrief/Statistics/touch/exit cases.
- The final cancellation/ENet run passed seven cases with process exit 0,
  including the fifth detached-view test added for removal during an active fade.
  Replacement palette bytes remain unchanged, and removed Statistics do not
  start a late fade or completion callback. Real ENet still agrees final results
  after pause/resume and holds native diagnostics through phase 3.
- All nine changed/new GDScript files pass formatter/linter checks;
  `git diff --check` passes. No native mechanics or loader code changed. Clean
  exits here do not prove the older intermittent Windows shutdown crash fixed.

Successful controller tests use named survival/result fixtures over a real
native renderer; they do not prove a naturally won network level. They verify
single capture from the physics completion branch, result gating, host-only
requests, frozen-frame read-only checks, both screens, waiting for the other fade,
all-dead routing, changed-state rejection and focus-loss detachment. Inspected
captures `build/network-live-summary-1.png`, `build/network-live-summary-2.png`
and `build/network-live-statistics-2.png` use that controlled result data (including
its warp flag). They are not phone screenshots or natural-win journey evidence.
The real ENet terminal tests use original game-over acknowledgement instead.

The preceding coordinator was pushed as `75fd2f6`.
The approved host Arcade continuation, campaign cursor,
retry/bonus/episode paths, later-level native loading and full multi-level
journeys remain next; the scoped loader approval is still pending. No APK/package
was handed over and the unavailable WSL/Linux exported-package gate was not run.

### Detached campaign-continuation proposal plan (2026-11-25)

Next prepare a session-owned, read-only continuation planner. Begin only from an
initial configuration accepted by the existing Arcade rules. Keep a private
campaign-script reader and copies of the initial level/entry/checkpoint metadata.
Validate the final result's canonical digest and source-configuration digest
before deriving any proposal. Cache one accepted result; identical repeated
requests are idempotent, while a conflicting result fails closed.

Derive the next script section from the current script's next_level, overridden
only by the existing collected-warp rule. Use the local campaign's native
adjust_difficulty and run_script calls with the original initial difficulty,
player-1 ending ship, all-player survival, cube count and two-player flag. Keep
the initial choice separate from the current two-player difficulty (+1 at New
Game). Any local difficulty-reference value remains explicitly subject to rule
review before native adoption; it is not an approved network gameplay rule.
Preserve the complete earned record, including both loadouts, 64-bit cash, carry,
lives and survivor flags; do not guess a new native setup or silently project
player-2 equipment into a future loader. Preserve all returned story/map/song/
autosave/mini-game/ending directives as data. Do not skip them or execute writes.

Normal all-dead results produce an explicit retry-required checkpoint proposal
without applying success rewards or difficulty adjustment. Bonus exits follow
the existing survival rule. If the script stops at a shop, expose a separate
preview for the already approved original Arcade Start choice: use the original
last map destination, or shop section + 1 when the map is empty. Keep shop entry
effects attached. No purchase system, menu transition, native load, save write or
live proposal adoption is introduced at this checkpoint.

Test canonical/context rejection and duplicate/conflicting results, all-player
versus any-player survival, ordinary and warp destinations, retry checkpoints,
both players' exact state retention and the Arcade map choice. Compare real
episode/difficulty proposals against the existing native campaign reader and
verify Game/local saves are untouched. Document unsupported or unresolved native
carry behavior instead of treating the pending loader approval as granted.

### Detached continuation planner and rule audit (2026-11-25)

Implemented `network_campaign_cursor.gd` as a read-only initial-level continuation
planner. It shares the initial validator's parsed campaign reader, avoiding a
second script-file read. Results must have the correct configuration context,
canonical hash and native-shaped fields. Proposals retain the whole earned
record, checkpoint and original script effects. Repeated identical results and
Arcade previews return copied cached data; conflicts, malformed state, unknown
stops and wrong parent digests fail closed. Native story/hint PackedStringArrays
are now supported by the bounded local canonical encoder; existing scalar and
integer-array encodings are unchanged.

The original native cube counter wraps as a u8, while the campaign reader clamps
its input to 0..4. The planner preserves the raw 0..255 value and passes it through
that existing API rather than introducing another clamp. A normal all-dead result
produces retry-required data with the original checkpoint/configuration, without
success adjustment. Bonus exit, any-player versus all-player survival, warp
destinations, Arcade's last-map/empty-map choice and ending directives are
preserved as data. No story/autosave directive is executed or silently removed.

The difficulty audit found two important boundaries:

- `new_game.gd::_start_game` sets two-player Arcade's current difficulty to the
  chosen initial difficulty + 1. Continuation's reference floor must use that
  current value, not the unraised menu choice; this was corrected before commit.
- `Game.campaign_level_finished` calls `TyrianCampaign.adjust_difficulty` using
  player 1's equipment-inclusive `total_score`. That bridge calls the one-player
  helper. `tyrian-sim::campaign::adjust_difficulty_mode` separately documents
  two-player thresholds and combined player cash. The existing local call is
  therefore a reference path requiring review, not independent proof of the
  original two-player behavior. The proposal labels its value `local_difficulty`,
  marks successful results `difficulty_rule_review_required`, and marks every
  proposal `requires_loader_adaptation`. No native setup adopts this value.

The native carry/equipment projection and difficulty discrepancy must be resolved
before live adoption; the prior scoped loader approval has not been assumed.
The raw earned record is not a serialized simulation or proof that the bridge's
carry fields cover every original transition. Future integration must also build
the planner from the same verified frozen content context as preparation, agree
proposal lineage on both peers and retain all original menu/story barriers.

Validation: all 15 assertions passed across seven new planner tests, four initial
configuration tests and four result tests. The final combined process then hit
the known Windows shutdown access violation (-1073741819), despite gdUnit's
successful summary. The isolated seven-case planner suite passed with actual
process exit 0. A separate seven-case real ENet/controller regression run also
passed with process exit 0. The planner tests compare all five episodes at six
difficulties (30 route combinations) to the existing native script reader, find
and preserve endings in all five episodes, verify wide cash/carry/player-2 state,
and check both selected Game fields and save-directory file hashes are unchanged.
This is script/reference-call coverage, not new independent C parity or a
multi-level player journey. All three changed/new scripts pass formatter/linter
checks and `git diff --check` passes. No APK/package or exported Linux gate was
run. The prior live Statistics checkpoint was pushed as `7b293e3`.
Live co-op remains the first-level prototype.

### Continuation agreement implementation plan (2026-11-25)

Add distinct fixed-size CONTINUATION, CONTINUATION_ACK and CONTINUATION_COMMIT
messages (68 bytes, existing digest payload). All use a positive final tick and
decision sequence 1/2: completed-level proposal, then original Arcade Start
preview. Only the host proposes/commits; only the guest acknowledges. Decision
2's local candidate must retain the committed proposal-1 digest as its parent.
No remote proposal object, equipment, script or Variant payload is decoded.

Use a pure session/input-epoch/final-tick-bound coordinator. Each peer derives its
own candidate before accepting a digest. A proposal may arrive before the guest
has finished deriving its candidate; retain at most the two bounded decisions,
acknowledging only after local verification. Require proposal -> acknowledgement
-> host commit, with idempotent duplicates, conflicting/skipped decisions failing
closed and a 30-second protocol/preparation timeout after proposal traffic starts.
Human waits between decisions have no timer. Commitment records agreement on
data only; it is never a simulation-load authorization.

Expose explicit backend prepare/propose/query APIs after completion's final fade
barrier. Before and after deriving candidates, verify preparation's frozen
content/client identity and unchanged final native diagnostic. Construct the
planner from that verified context. Recheck the context when accepting controls;
discard valid stale sessions/epochs and reject future epochs, spoofed roles,
wrong ticks, mismatches and premature acknowledgements/commits. Stop/disconnect
clears proposals/coordinator without advancing, replacing or reseeding native
simulation. Preserve the planner's loader/difficulty-review flags.

Test codec fixtures and strict ranges, pure adverse delivery and bounded early
proposals, both original Arcade decision choices and real ENet agreement after
final-result/fade synchronization. Verify unchanged native state and copied
committed data, conflict/context rejection and disconnect cleanup. Re-run relevant
completion, planner and player tests. Keep these APIs detached from the live
first-level player's lobby exit until the approved native/cursor adoption is
implemented. No menu, gameplay, loader or save behavior changes in this step.

### Read-only continuation agreement checkpoint (2026-11-25)

Implemented the three digest-only wire kinds, `network_continuation.gd` and
explicit post-fade backend preparation/proposal/query APIs. Each peer derives its
own sealed candidate, verifies configuration/result lineage and review flags,
and compares the digest. The backend checks the agreed completion digest itself
as well as the unchanged native diagnostic, so a corrupted local result object
cannot silently replace the agreed record. Frozen content/client identity is
verified around candidate derivation and on new controls. Decision 2 is the
original Arcade preview with sequence 2 and the committed decision-1 parent.

Only the host proposes/commits and only the guest acknowledges. Early proposals
wait for local derivation; conflicting/skipped/premature controls fail closed.
The two-entry history handles duplicates without resetting deadlines or repeating
filesystem hashing. New decisions and explicit preparation still reverify the
frozen context. Human waits between decisions have no timer; an active exchange
has a 30-second preparation/protocol deadline. Committed queries return copied
data, retaining loader/difficulty-review flags. Stop/failure clears all candidate
and coordinator references without replacing or stepping the native node.

Validation:

- The final continuation/pure/ENet/planner/codec run passed 23 cases with actual
  process exit 0. Its inherited native completion cases are included in that
  count. Real ENet verifies retry proposals after pause/resume at epoch 2,
  unchanged native identity/diagnostics, copied data, stale-epoch rejection,
  detection of a corrupted agreed result, mismatched candidates and cleanup.
- A controlled shop/Arcade routing fixture exercises both decision exchanges
  and parent retention over real ENet. It does not claim a naturally won level
  or a live campaign journey. Real script/routing behavior is covered separately
  by the planner tests. Four duplicate commit packets leave the instrumented
  filesystem-verification count unchanged.
- The separate player/lobby/Pause/result regression run passed 16 cases with
  actual process exit 0. The two final runs therefore cover 39 distinct cases.
  All nine changed/new GDScript files pass formatter/linter checks and
  `git diff --check` passes.
- An earlier five-case ENet run passed its assertions, then hit the existing
  Windows native shutdown access violation (-1073741819). Later clean exits do
  not establish that this intermittent crash is fixed.

These APIs remain detached from the live first-level player's lobby exit. A
digest commit is agreement on read-only data, not permission to load a simulation
or apply the unresolved difficulty reference. Live host Arcade binding,
cursor/native adoption, retry/ending routes and multi-level journeys remain next.
The scoped mechanics approval is still pending. No APK/package, phone execution
or exported Linux gate is claimed. The preceding planner checkpoint was pushed
as `24de5d4`.

### Approved later-level loader and difficulty plan (2026-11-25)

The maintainer expressly approved: "Approve scoped network loading and two-player
difficulty adaptation." This authorizes the network-only adaptation and its
verification; it does not authorize rebalancing or changing ordinary local play.
The earlier pending-approval notes above are historical and superseded here.

Implementation order and audit boundaries:

1. Preserve the strict initial configuration and prepare_network_level APIs.
   Add a distinct detached continuation loader with a validated 21-field level
   configuration, exact seven-value carry and bonus-level flag. Accept adjusted
   difficulty, full u64 cash and both ending equipment sets. Treat player 1 rear
   power and player 2 front power as the existing byte-sized lives counters,
   including zero; retain ordinary 1..11 validation for actual weapon powers.
   Continue validating named catalog entries and real/modded level data.
2. Retain existing setup order: load tables/level, original initial difficulty,
   two-player modes/equipment/cash, processor/effects, carry and mod application,
   then create the simulation, private stars and presentation. Require a fresh
   native node; never reload or mutate the old running/ended simulation. Add an
   opt-in core constructor so full player-1 cash and player-2 sidekick carry are
   present before HUD initialization and loop_top. The ordinary constructor's
   behavior must remain unchanged. Preserve friction/special-fire bits exactly;
   do not invent a new alive/revival rule or restore unrelated transient state.
3. Add a network-specific native campaign difficulty method using the existing
   software-arithmetic two-player helper and combined cash. Preserve raw unsigned
   cash via strict hexadecimal strings and the core's wrapping currency
   arithmetic. Keep the existing local one-player bridge unchanged. The network
   continuation planner may then record the approved network difficulty separately
   from the audited local reference and remove only its difficulty-review marker.
4. Build a separate strict GDScript next-level request from a sealed continuation
   proposal, original configuration, explicit agreed seed and script level stop.
   Retain carry, source/parent lineage and bonus flag; reject shops, story-only
   stops, mini-games and retry/episode transitions until their respective owners
   handle them. Do not weaken startup validation or infer a new input epoch.
5. Verify core default-path equivalence, cash/lives/sidekick/friction/special
   restoration at tick zero, tick/RNG equality against reference setups, and
   deterministic repeated loads. Verify difficulty threshold boundaries,
   monotonicity, combined cash and u64 edge cases. Test native API strict rejection,
   private effects/peer isolation, unchanged old node and two peers preparing the
   same next level. Rebuild the Windows library before Godot tests; cross-compile
   ARM64 where available and report actual exits and unavailable package checks.
6. Only after adapter checks pass, integrate fresh owned next-level preparation,
   proposal/load/view-ready barriers and the approved host Arcade continuation.
   Keep old views detached before freeing their native owner. This loader
   checkpoint alone must not be described as completed multi-level gameplay.

The audit found that LevelCarry's existing bridge has seven values: four friction
counters, held special fire, and player-2 sidekick level/series. World startup
currently restores sidekick progression only for Endless. The network opt-in
path will restore that carried progression before draw_options, without changing
ordinary campaign/Endless startup. Full u64 player-1 cash likewise must precede
credits_start and startup script evaluation; a post-load setter is insufficient.
The local c-final tag is unavailable, so comparisons with existing core/reference
paths and covered frozen goldens are not new independent C transition recordings.

### Fresh continuation ownership implementation order

After adapter validation, add a detached preparation fork before changing the
live player. The old context must retain its ended native node while a fresh
context captures the same selected content, compares the complete source identity,
builds the next request from the locally sealed proposal and explicit agreed seed,
validates continuation equipment and prepares its own tick-zero native node.
Retain the request/script/parent lineage in copied accessors. Repeated preparation
must reverify the new diagnostic. Reject different requests, source edits and
unsupported script effects. Test independent peers, old-node lifetime, new-node
cleanup, no Game/save writes and unchanged strict initial validation. Only then
add the network load/activation barrier and scene ownership transfer; these remain
separate from this detached fork and must not reuse the ended runner or input epoch.

### Detached loader checkpoint (2026-11-25)

Implemented the approved Rust opt-in constructor and fresh-node native
`prepare_network_continuation` API. They preserve full player-1 cash before
credits_start/loop_top, carried player-2 sidekick progression before HUD drawing,
the existing friction/special bits, both equipment sets and zero/byte-sized lives.
Ordinary construction and the strict initial loader keep their existing rules.
The separate campaign API applies the existing software-arithmetic two-player
helper to the wrapping sum of both unsigned cash counters. The planner records
`network_difficulty` alongside the unchanged `local_difficulty` audit reference;
its difficulty-review flag is now resolved. Loader adaptation remains marked on
the read-only proposal until an actual request is prepared.

`network_next_level.gd` builds copied, sealed requests from a locally derived
level proposal, its source configuration/result/parent and an explicit agreed
seed. Initial configuration validation is unchanged. New validation allows only
the two lives counters to depart from weapon power bounds, adjusted difficulty
and the existing network device/pacing profile. Invalid gear still fails native
catalog checks. Shops, retries, episode/title/eof stops, mini-games, story screens
and pending autosaves are refused here; their owners must handle them first.
No story, save, epoch or progression effect is silently applied.

`NetworkPreparation.fork_continuation` captures independent frozen content and
source identity, validates the request and owns its fresh tick-zero preview.
The old node stays alive. Returned request/entry/configuration data are copies;
clearing/failing one fork releases only its own native node. Startup validation
cannot replace a continuation's accepted configuration.

Validation of this checkpoint:

- Four new core tests passed: ordinary constructor equivalence over three
  episodes, exact carried state before the first tick, independent carried-peer
  ticks/RNG, and unsupported-profile rejection.
- All native bridge unit tests passed: 64 passed, three existing ignored tests.
  The new helper tests cover strict carry/money parsing, the 62,500 combined-cash
  threshold, monotonicity, wrapping sums and existing extreme-value conversion.
  One initial test incorrectly expected huge cash to saturate difficulty; the
  audited core helper instead converts through its existing wrapping i64 path.
  The adapter retains that behavior rather than changing arithmetic policy.
- Strict frozen two-player respawn/link/linked recordings match all groups and
  level endings: 7,197/7,197 ticks across three recordings. This does not prove
  new independent C parity for later-level transitions.
- The final loader/planner/preparation Godot run passed 21 tests with actual
  process exit 0, including fresh fork lifetime/cleanup, two-peer diagnostics,
  unchanged old node, malformed requests/catalog entries and separate local vs
  network difficulty. Formatter/linter checks pass for all six affected scripts
  and tests; Rust formatting and scoped clippy pass with the two pre-existing
  lint exceptions documented in prior checkpoints.
- Windows release and Android ARM64 release builds succeeded. No APK, device
  play or exported Linux journey/smoke gate is claimed. The intermittent native
  Windows shutdown crash remains unresolved despite these clean exits.
- The five-case ENet continuation/completion regression passed assertions on
  both runs. The earlier run exited 0; the final run after the preparation-fork
  change exited -1073741819 (0xC0000005) during shutdown, after gdUnit reported
  success. The final process run therefore did not pass cleanly. It reproduces
  the pre-existing shutdown issue; this checkpoint does not establish its cause
  or fix it. No assertion failures or orphan nodes were reported.

The live first-level player still exits after Statistics. Next: bind the new
owned preparation to an explicit load/digest/activation barrier, allocate a fresh
input epoch, adopt later-level campaign cursor context, and detach old views
before releasing their owner. Then connect the already approved host-operated
Arcade progression and verify a real multi-level journey. No further mechanics
approval is needed for the scoped adaptation implemented above.

Live integration must also explicitly adapt consumers that currently accept only
initial configurations: touch policy/runner activation, HUD/view binding and its
Ready digest, result capture, and cursor begin/adoption. They must select the
continuation grammar only for an agreed owned request, retaining strict startup
validation. Pause/resume epochs and delayed old-level packets must remain distinct
from the new tick-zero epoch. NetworkSession's current scene-exit hook stops the
backend, so planned replacement needs a guarded detach/adopt path before its old
view exits. The detached fork does not bypass any of these existing checks.

### Next-level load agreement implementation plan (2026-11-25)

Before scene replacement, add a pure bounded load coordinator and explicit
backend APIs. Bind one load attempt to the committed continuation decision,
session, current post-pause input epoch and final presented tick. Reserve exactly
epoch+1 for the next tick-zero runner; reject overflow. The host offers an exact
u64 seed, both peers fork their own locally derived committed proposal, and each
announces a digest covering proposal, seed, next epoch, copied request and native
tick-zero diagnostic. Only matching loaded announcements permit a host activation
control. Guest activation requires its own successful preparation and both loaded
announcements. No native node is stepped, adopted, freed or exposed to a new view
by this coordinator. Stop/failure releases only the pending owned preparation.

Use three new fixed-size gameplay controls: seed (44 bytes), loaded digest (68)
and host activation digest (68), retaining the existing 72-byte cap. Bind sender
roles and decision sequence 1/2, reject malformed/conflicting/premature controls,
ignore stale sessions/epochs, and preserve idempotence without resetting the
30-second active-exchange deadline. No deadline runs before the explicit host
offer or after commitment. Independently reverify frozen content, agreed final
result/native state and pending preview before load/activation operations. Reuse
the existing transport with no remote object deserialization. Test pure protocol
ordering, duplicates, timeout and context rejection, then real ENet with native
forks, mismatch cleanup, old-node lifetime and no change to the ended runner.
Live flow/cursor/view ownership migration remains the subsequent operation.

### Backend load barrier checkpoint (2026-11-25)

The preceding detached loader checkpoint was committed and pushed as `3cdcbba`.
The next source change adds `network_level_load.gd`, plus gameplay controls
LOAD_SEED (13, 44 bytes), LOAD_READY (14, 68 bytes) and LOAD_ACTIVATE (15, 68
bytes). Header version and maximum size remain unchanged; the existing complete
client-source identity prevents mixing this client with an older implementation.
The seed payload is its exact eight hexadecimal-decoded bytes. Loaded/activation
digests cover the independently derived proposal, exact seed, reserved next epoch,
full canonical request digest and tick-zero native diagnostic.

`prepare_next_level(sequence, seed)` is host-only and requires a locally committed
level continuation after phase-3 fades. The guest independently derives and
prepares the same committed candidate when the offer arrives. `next_level_loaded`
requires matching local and remote diagnostics; `commit_next_level_load` is an
explicit host operation that rechecks the ended result/core/content and pending
preview. `next_level_load_committed` records authorization only. The copied
`next_level_request` accessor does not transfer ownership or expose a borrowed
native node to a view. Epoch+1 is reserved in the coordinator, not installed into
the old runner. Neither ticks nor original view ownership change at this stage.

Controls bind the old final tick/current input epoch and decision sequence.
Wrong/future contexts, changed seeds/digests, premature activation and timeout
fail closed. Duplicate history is bounded to this single load and checks conflicts
without repeating filesystem verification or extending the deadline. Either
backend stop/failure releases its pending preparation. The original ended node
remains alive during healthy agreement, and normal session failure releases it
through the existing owner/view cleanup path.

Pure load/codec/continuation suites passed 17 test cases; that process
then reproduced the existing native shutdown access violation (-1073741819).
An initial test-discovery error from method calls in GDScript constant initializers
was corrected to literal fixture strings before this run. The new native ENet
case uses a controlled level-stop proposal after a natural all-dead terminal
result, so it does not claim a successful campaign journey. Live progression,
cursor/view/runner adoption and later-level UI remain unconnected.

The final ENet run passed six cases (the new load case plus five inherited
continuation/completion regressions), with no errors, failures, skips or orphans
and actual process exit 0. The load case verifies host-only offer/activation,
post-pause epoch 3 reservation, identical independently prepared native requests,
untouched old ticks/nodes/views during agreement, copied request data, duplicate
activation without extra filesystem checks, stale-seed rejection and changed
pending-preview detection with cleanup on both peers. The pure suites verify
request/state/proposal mismatches, premature controls, codec roles/sizes/types,
context/epoch overflow and deadlines that duplicate packets cannot extend.
All five changed/new GDScript files pass formatter/linter checks and
`git diff --check` passes. These clean ENet exits do not resolve the intermittent
shutdown failure seen in the pure run. No native rebuild was needed for this
GDScript-only checkpoint; no APK, phone play or exported Linux gate is claimed.

### Fresh runner adoption plan (2026-11-25)

The load-barrier checkpoint was pushed as `c163126`. Next add explicit backend
adoption, without changing the live Statistics/Arcade scene flow yet. Extract
the continuation configuration grammar into a small dependency-only module so
result/cursor/input consumers can select it without circular preloads or weakening
initial validation. Add a sealed-request runner entry point; keep ordinary
activation strict. Carry the selected profile through frame validation and result
capture; adopt the request's real script context into a fresh campaign cursor.

Register weak view borrows at binding and release them at detach/exit. Adoption
requires committed load authorization, unchanged ended result/core/content,
unchanged pending tick-zero diagnostic and no remaining old view borrows. Build
fresh runner/pause/cursor objects before replacing the preparation owner. Use the
reserved epoch+1, tick zero and the agreed request's configuration and metadata;
reset view/result/continuation/load state, then release the detached old owner.
Keep the persistent transport/startup handshake separate from the active gameplay
epoch. All future pause/result/load controls use that active context.

Permit one correctly bound next-epoch view Ready to arrive before local adoption,
only after local load commitment, with exact next-config digest. Stage it without
stepping or marking the old view ready. New-level input capture and advancement
remain blocked until both fresh views are ready. Ignore old-epoch controls after
adoption. Test rejection while a view is borrowed, safe detach/lifetime, two-peer
adoption with staggered Ready delivery, tick/RNG equivalence, pause/resume in the
new epoch, copied later-level metadata/result capture and strict initial APIs.
Use the already chosen original two-player HUD; this step adds no new layout.
Live scene replacement and the approved host Arcade route follow separately.

### Backend adoption checkpoint (2026-11-25)

Implemented explicit `adopt_next_level`, weak view-borrow registration and release,
fresh continuation runner/pause/cursor creation, and a separate active gameplay
context. The persistent startup transport remains connected. Adoption refuses
while an old view is bound; detach/exit removes its borrow and disconnects the
old callbacks. It rechecks the ended result/content, pending preview and sealed
request, constructs replacements, then rechecks snapshots around script parsing
and compares the request/state against the already committed load digest. Only
then does it swap owners and free the old preparation. No simulation tick occurs
during adoption.

The new runner starts at tick zero in the reserved epoch, with a fresh input
buffer. It requires the continuation-specific sealed request; ordinary activation
keeps strict initial validation. `network_level_configuration.gd` centralizes the
continuation grammar without circular dependencies; the existing next-level
builder delegates to it. Input policy, result capture and campaign cursor adoption
select that profile explicitly. The original view binds the adopted request's
real level metadata instead of the initial destination. Initial APIs and the
existing original two-player HUD remain unchanged.

One valid next-epoch view Ready may be staged while the peer still owns its old
ended view, but only after local load commitment and with the exact next config
digest. Adoption preserves that staged fact while resetting all old view/result/
load state. Fresh capture/advance are blocked until both new views are ready.
Old-epoch controls are discarded after adoption, including before the new view
barrier has finished. Pause/resume and later results/continuations use the adopted
epoch/configuration and script context.

Validation:

- The loader/runner/cursor run passed 28 executed cases with actual process exit
  0; counts include inherited loader cases exercised again in the new suite.
  New tests compare 80 ticks from independent carried runners and verify strict
  initial activation, sealed-request rejection and later-level result/cursor
  digest selection.
- A full seven-case ENet adoption/load/continuation/completion regression passed
  with actual process exit 0. Its controlled next-level fixture verifies refusal
  with old views attached, safe native lifetime, staggered adoption and early
  Ready staging, original new-level metadata, equal native diagnostics through
  35 new ticks, new-epoch Pause/Resume and stale result rejection. It uses a
  controlled level-stop proposal after natural all-dead completion, not a won
  multi-level player journey.
- After tightening the final pre-swap snapshot/digest guard and bonus-flag
  validation, 24 view/result/adoption cases passed with exit 0, followed by two
  focused request/cursor tests and the focused ENet adoption case, also exit 0.
  Inherited tests were excluded from the focused commands rather than rerun.
- Initial failures came from missing summary fields in a fake result and a test
  profile path containing unresolved parent components. The fixture and command
  profile setup were corrected; final commands use absolute normalized profiles.
  All eleven changed/new GDScript files pass formatter/linter checks and
  `git diff --check` passes. No native rebuild, APK, physical-device run or exported
  Linux gate is claimed. Clean exits do not establish that the pre-existing
  intermittent native shutdown issue is fixed.

At this checkpoint these backend APIs were not yet invoked by the live first-level Statistics exit.
Next wire NetworkSession's guarded scene replacement and the approved host-owned
original Arcade continuation, including its waiting guest. Before live later-level
completion, adapt debrief binding to the explicit continuation profile; preserve
the current strict initial binding. Handle story/autosave effects, retry and
episode-ending routes through their own owners rather than bypassing the request
builder's existing refusals. No new frontend layout or mechanics approval is
needed to reuse the directions already selected for this scoped work.

### Live continuation scene plan (2026-11-26)

The adoption checkpoint was pushed as `bd727eb`. Reuse the already approved
host-operated original Arcade menu, its original Options screen, waiting guest
lobby and original two-player HUD; no new layout is proposed. After both final
Statistics fades, NetworkSession owns a deferred progression state machine:
derive/agree decision 1, open the host Arcade menu for a shop while the guest
waits, agree decision 2 after host Start, then offer/load/activate/adopt a fresh
level and replace each waiting scene with the original player scene. Direct
level stops can proceed through the same load/adoption path without an extra
shop. Normal all-dead completion retains the current exit. Retry, episode/title/
eof stops and pending story/autosave/mini-game effects must exit explicitly rather
than silently skip their owners. Read-only native route inspection confirms
episode 1 section 4 is a shop with no such effects in this two-player context.

Queue every scene-changing operation outside backend signal delivery. Check
backend/scene identity, Android platform and session state before each operation;
detach the old player and release its borrow before replacing it, and guard the
existing scene-exit hook so an intentional interlude does not stop the session.
Keep ended native ownership through the menus until committed adoption. Preserve
the original engine-rate restore value across successive levels. Guest waiting
and host loading reuse existing lobby labels with disabled startup actions;
Arcade Start is the explicit host progression action, not a second startup
negotiation. Disconnect, cancel, focus loss or failed preparation stops the
session and clears pending work without reviving a stale scene callback.

Render both earned cash values in the original Arcade/Options positions without
mutating Game's local campaign/loadout/save data; retain fixed phone assignments
and disabled purchases/save/load. Add an explicit continuation debrief binding
profile, selected only by an adopted backend. Preserve strict initial binding.
Test deferred routing, ownership and stale-callback rejection with controlled
session fixtures; exercise the original menu's Start/Options actions and guest
waiting state; retain real ENet native adoption regression coverage. A controlled
successful-result fixture is not evidence of a naturally won multi-level journey
or two physical phones, and the validation report must distinguish them.

### Live continuation checkpoint (2026-11-26)

The live Statistics phase-3 callback now requests continuation from NetworkSession
once, disables old input and retains the ended native owner. Session progression
uses deferred, generation/backend-checked work: agree decision 1, reuse the host
Arcade menu for a shop with the guest in the existing waiting lobby, agree the
host Start choice, offer/load/compare/activate the next level, detach the old view,
adopt the prepared owner and replace each waiting scene with its new player.
Direct level stops use the same load/adoption route. Startup Ready/Start cannot
be reused during this interlude; the approved host Arcade Start is the action
that proceeds, followed by the existing machine load and two-view barriers.

The original Arcade/Options layouts render copied earned equipment and exact
unsigned cash text. Fixed phone assignments and disabled purchase/save/load rows
remain. No Game campaign/loadout/save state is adopted into the local profile.
An explicit continuation profile now binds later-level debriefs; default initial
binding stays strict. The original physics-rate restore value survives successive
player scenes. Intentional old-view exit cannot stop the new player; unexpected
exit defers backend cleanup outside Godot's tree-removal callback and binds that
cleanup to the exited backend. Cancel/focus loss/disconnect clears pending work;
stale generations and scene replacement cannot revive an old progression.

Normal all-dead results retain their exit. Story/autosave/mini-game effects,
retry, bonus-death and episode/title/eof routes remain incomplete and are not
silently applied. The source now links supported continuation, not every campaign
path. No new frontend direction was needed: it reuses the already selected
host Arcade/Options, guest lobby, original HUD and shared Statistics directions.

Validation:

- The final session/menu/Options/debrief/player run passed 24 cases, with no
  errors, failures, skips or orphans and actual process exit 0. It covers host
  and guest routing, one-shot decisions/load requests, stale generation and
  cleanup callbacks, focus cancellation, unsigned cash text, rate restoration,
  changed earned-cash rendering, original Options navigation, continuation Start
  returning to the same session, explicit debrief binding and the player phase-3
  continuation callback firing only once.
- A focused real-ENet scene test passed with actual process exit 0. Two actual
  session drivers agree the original episode-1 section-4 shop and Start route,
  retain old native ownership through their interludes, replace both player
  views using the new runner adoption, and match native diagnostics through 35
  ticks of the next level. The interlude scenes are fixture nodes; the original
  Arcade/Options/lobby widgets are exercised separately above. The native scene
  test uses a controlled successful-route candidate after natural all-dead
  completion, bypassing the player's surviving-result UI condition. It does not
  establish a naturally won multi-level or two-phone journey. Inherited ENet
  regressions were excluded from this focused command; earlier checkpoints
  record their full runs.
- The first scene test reached teardown but reported busy-parent removal errors
  and exited with a native access violation. The unexpected player-exit callback
  was freeing a sibling backend during tree removal. Deferring identity-bound
  cleanup removed those errors in the final run. This concrete fix does not
  establish that the earlier intermittent Windows shutdown issue is resolved.
  An initial pure fixture also dereferenced a backend that had correctly been
  freed on failure; it now checks lifetime directly.
- All ten changed/new GDScript files pass formatter/linter checks;
  `git diff --check` passes. No native rebuild, APK, physical phone run or
  exported Linux journey/smoke gate is claimed.

Next verify an independently running, naturally won multi-level journey and
complete original story/autosave, retry/bonus-death and ending-route ownership
before describing this as full campaign co-op. Internet bootstrap remains a
separate unfinished part of the original plan.
