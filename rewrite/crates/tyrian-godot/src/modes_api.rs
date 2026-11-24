//! Inputs and HUD of the side modes exposed to Godot.
//!
//! - `set_mouse`: mouse of the next tick, like `golden_master.c:golden_master_inject`
//!   (`mouse_pressed[]` taken as bits of the keyboard mask, relative movement
//!   `keyboard.c:mouseGetRelativePosition`); the simulation applies it to the player
//!   whose `inputDevice` is 0 or 2 (`player_movement.c:JE_playerMovement`).
//! - `mode_hud`: what the modes HUD must display (lives, timer, Galaga).

use godot::prelude::*;
use sha2::{Digest, Sha256};
use tyrian_sim::modes::MouseInput;
use tyrian_sim::Loadout;
use tyrian_sim::{GeneratorId, ShieldId, ShipId, SidekickId, SpecialId, WeaponId};

use crate::TyrianSim;

#[godot_api(secondary)]
impl TyrianSim {
    /// Conservative same-build diagnostic, not the legacy replay state hash.
    /// Compare at identical observer-consumption boundaries; never use as a save.
    #[func]
    fn network_diagnostic_digest(&self) -> GString {
        if self.replay.is_some() || self.recorder.is_some() {
            return GString::new();
        }
        let Some(bytes) = self.sim.as_ref().and_then(|sim| sim.network_diagnostic_bytes()) else {
            return GString::new();
        };
        GString::from(format!("{:x}", Sha256::digest(bytes)).as_str())
    }

    /// Identity of native sources/dependencies embedded in this loaded binary.
    /// Independent of the user-editable application release label.
    #[func]
    fn network_build_id(&self) -> GString {
        env!("TYRIAN_NETWORK_BUILD_ID").into()
    }

    /// Mouse of the next `step`: `mask` in bits of the keyboard mask (0x10 fire,
    /// 0x20 fire switch, 0x40 / 0x80 sidekicks), `dx`/`dy` in game pixels.
    #[func]
    fn set_mouse(&mut self, mask: i32, dx: i32, dy: i32) {
        if let Some(sim) = self.sim.as_mut() {
            sim.set_mouse(MouseInput { mask: (mask & 0xf0) as u8, dx, dy });
        }
    }

    /// Network sessions only: one pointing device per player. Button ownership,
    /// device selection, linking and movement are still handled by the core.
    #[func]
    fn set_player_mice(&mut self, p1_mask: i32, p1_dx: i32, p1_dy: i32, p2_mask: i32, p2_dx: i32, p2_dy: i32) {
        if self.replay.is_some() {
            return;
        }
        if let Some(sim) = self.sim.as_mut() {
            sim.set_player_mice(Some([
                MouseInput { mask: (p1_mask & 0xf0) as u8, dx: p1_dx, dy: p1_dy },
                MouseInput { mask: (p2_mask & 0xf0) as u8, dx: p2_dx, dy: p2_dy },
            ]));
        }
    }

    #[func]
    fn clear_player_mice(&mut self) {
        if let Some(sim) = self.sim.as_mut() {
            sim.set_player_mice(None);
        }
    }

    /// Analog stick of players 1 and 2 for the following ticks, in
    /// values reduced by `joystick.c:joystick_axis_reduce` (controls.gd).
    /// Ignored while playing back a `.rep`: its inputs come from the file.
    #[func]
    fn set_analog(&mut self, p1x: i32, p1y: i32, p2x: i32, p2y: i32) {
        if self.replay.is_some() {
            return;
        }
        if let Some(sim) = self.sim.as_mut() {
            sim.set_analog([(p1x, p1y), (p2x, p2y)]);
        }
    }

    /// `newkey` of the next tick: a key was pressed since the
    /// previous one (closes the "Game Over" screen, tyrian2.c).
    #[func]
    fn set_new_key(&mut self, pressed: bool) {
        if self.replay.is_some() {
            return;
        }
        if let Some(sim) = self.sim.as_mut() {
            sim.set_new_key(pressed);
        }
    }

    /// Additions to `set_modes` (golden masters v2, "mode" line: `cash a:b`,
    /// `initdiff`, "items2" line): money of both players, initial difficulty
    /// and equipment of player 2 (same order as `set_loadout`, 10
    /// values without money; empty array = no items2). To be called after
    /// `set_modes`, before `load_level`.
    #[func]
    fn set_modes_extra(&mut self, cash_p1: i64, cash_p2: i64, initial_difficulty: i32, loadout2: PackedInt32Array) {
        self.modes.cash = (cash_p1.max(0) as u64, cash_p2.max(0) as u64);
        self.modes.initial_difficulty = initial_difficulty.clamp(0, 255) as u8;
        let v = loadout2.as_slice();
        self.modes.loadout2 = (v.len() >= 10).then(|| {
            let b = |i: usize| v[i].clamp(0, 255) as u8;
            Loadout {
                ship: ShipId(b(0)),
                front_weapon: WeaponId(b(1)),
                front_power: b(2),
                rear_weapon: WeaponId(b(3)),
                rear_power: b(4),
                shield: ShieldId(b(5)),
                generator: GeneratorId(b(6)),
                left_sidekick: SidekickId(b(7)),
                right_sidekick: SidekickId(b(8)),
                special: SpecialId(b(9)),
                cash: 0,
            }
        });
    }

    /// State displayed by the modes HUD:
    /// - `two_player`, `galaga`, `one_player_action`, `timed` (tyrian2.c:JE_main);
    /// - `lives_p1`, `lives_p2`: `*player[p].lives` = power of the weapon of port p
    ///   (mainint.c:JE_initPlayerData, displayed by mainint.c:JE_drawPlayerInfo);
    /// - `level_timer`, `level_timer_countdown` (tyrian2.c: "%d.%d" hundredths);
    /// - `galaga_life`: next life threshold (tyrian2.c, "Shield Gen" block).
    #[func]
    fn mode_hud(&self) -> VarDictionary {
        let Some(sim) = self.sim.as_ref() else {
            return VarDictionary::new();
        };
        let w = sim.world();
        vdict! {
            "two_player" => w.two_player_mode,
            "galaga" => w.mode.galaga_mode,
            "one_player_action" => w.one_player_action,
            "timed" => w.mode.timed as i32,
            "lives_p1" => w.players[0].lives(0) as i32,
            "lives_p2" => w.players[1].lives(1) as i32,
            "level_timer" => w.script.level_timer,
            "level_timer_countdown" => w.script.level_timer_countdown as i32,
            "galaga_life" => w.mode.galaga_life as i64,
            // tyrian2.c: allPlayersGone (final explosion then "Game Over").
            "all_players_gone" => w.ending.all_players_gone,
        }
    }
}
