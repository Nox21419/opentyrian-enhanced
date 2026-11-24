# Two-phone co-op: connection screen and implementation stages

## Current status (2026-11-24)

**Network gameplay is not implemented yet.** New Game > Modem/Network Game
now opens a connection-only LAN lobby. It has Host Game, Join Game and Back,
using the original picture-2 backdrop, bitmap fonts, palette and menu engine.
Android activates the wider invisible row targets on release; dragging off
cancels. Desktop mouse, keyboard and controller navigation remain available.
All text is localized in the six game languages.

The host Episode and Difficulty checkpoints are implemented and approved: while hosting,
Join Game becomes **Choose Episode**. It reuses the original Episode screen and
then opens the original Difficulty screen. Choosing Difficulty returns to the
same live lobby with both choices shown. Back preserves the host connection;
leaving the lobby stops it and clears both choices. No save/profile is written.

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

For the host Episode checkpoint, Host Game first, then Choose Episode. Choose
an available episode, then Difficulty, or Back; the connection remains open.
Reopening the screens restores selected rows. The host may make this preparation
choice before a guest connects. The choice is local preparation, not a broadcast
configuration or a guest Ready acknowledgement. Both screens were approved;
Ready and level integration are still pending.

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
