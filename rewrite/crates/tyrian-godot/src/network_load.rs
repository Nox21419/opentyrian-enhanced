//! Detached initial-Arcade preview. Never touches bridge presentation globals.
use godot::prelude::*;
use tyrian_sim::{modes::ModeSetup, LevelCarry, Loadout, PlayerCarry, Sim};

use crate::TyrianSim;

fn integer(d: &VarDictionary, key: &str, low: i64, high: i64) -> Option<i64> {
    let v = d.get(key)?;
    if v.get_type() != VariantType::INT {
        return None;
    }
    let n = v.try_to::<i64>().ok()?;
    (low..=high).contains(&n).then_some(n)
}

fn boolean(d: &VarDictionary, key: &str) -> Option<bool> {
    let v = d.get(key)?;
    (v.get_type() == VariantType::BOOL).then(|| v.try_to::<bool>().ok()).flatten()
}

fn text(d: &VarDictionary, key: &str) -> Option<String> {
    d.get(key)?.try_to::<GString>().ok().map(|s| s.to_string())
}

fn hex(d: &VarDictionary, key: &str) -> Option<u64> {
    let s = text(d, key)?;
    unsigned_hex(&s)
}

pub(crate) fn unsigned_hex(s: &str) -> Option<u64> {
    if s.len() != 16 || !s.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)) {
        return None;
    }
    u64::from_str_radix(s, 16).ok()
}

pub(crate) fn continuation_difficulty(current: i32, initial: i32, cash1: &str, cash2: &str) -> Option<u8> {
    if ![1, 2, 3, 4, 6, 8].contains(&initial) || !(initial + 1..=9).contains(&current) {
        return None;
    }
    let cash = unsigned_hex(cash1)?.wrapping_add(unsigned_hex(cash2)?);
    Some(tyrian_sim::campaign::adjust_difficulty_mode(current as u8, initial as u8, cash, true))
}

fn continuation_carry(v: &[i32]) -> Option<LevelCarry> {
    if v.len() != 7 || !(0..=1).contains(&v[4]) || v[5..].iter().any(|n| !(0..=255).contains(n)) {
        return None;
    }
    Some(LevelCarry {
        players: [
            PlayerCarry { x_friction_ticks: v[0] as u32, y_friction_ticks: v[1] as u32, ..Default::default() },
            PlayerCarry {
                x_friction_ticks: v[2] as u32,
                y_friction_ticks: v[3] as u32,
                sidekick_level: v[5] as u8,
                sidekick_series: v[6] as u8,
            },
        ],
        special_fire_held: v[4] != 0,
    })
}

fn array(d: &VarDictionary, key: &str, count: usize) -> Option<Vec<i32>> {
    let a = d.get(key)?.try_to::<VarArray>().ok()?;
    if a.len() != count {
        return None;
    }
    a.iter_shared()
        .map(|v| {
            if v.get_type() != VariantType::INT {
                return None;
            }
            let n = v.try_to::<i64>().ok()?;
            (0..=255).contains(&n).then_some(n as i32)
        })
        .collect()
}

fn loadout(v: &[i32]) -> Loadout {
    Loadout {
        ship: tyrian_sim::ShipId(v[0] as u8),
        front_weapon: tyrian_sim::WeaponId(v[1] as u8),
        front_power: v[2] as u8,
        rear_weapon: tyrian_sim::WeaponId(v[3] as u8),
        rear_power: v[4] as u8,
        shield: tyrian_sim::ShieldId(v[5] as u8),
        generator: tyrian_sim::GeneratorId(v[6] as u8),
        left_sidekick: tyrian_sim::SidekickId(v[7] as u8),
        right_sidekick: tyrian_sim::SidekickId(v[8] as u8),
        special: tyrian_sim::SpecialId(v[9] as u8),
        cash: 0,
    }
}

impl TyrianSim {
    fn detached_level(&mut self, data: &str, d: &VarDictionary, carry: Option<LevelCarry>, bonus: bool) -> Option<Sim> {
        if d.len() != 21 || text(d, "mode")? != "arcade" {
            return None;
        }
        let ep = integer(d, "episode", 1, 5)? as u8;
        let level = integer(d, "level_file", 1, 65535)? as u16;
        let initial = integer(d, "initial_difficulty", 1, 8)? as u8;
        if ![1, 2, 3, 4, 6, 8].contains(&initial) {
            return None;
        }
        let difficulty = integer(d, "difficulty", 2, 9)? as u8;
        if (if carry.is_some() { difficulty < initial + 1 } else { difficulty != initial + 1 })
            || array(d, "devices", 2)? != [0, 0]
        {
            return None;
        }
        let seed = hex(d, "seed")?;
        let cash = (hex(d, "cash1")?, hex(d, "cash2")?);
        if carry.is_none() && cash != (0, 0) {
            return None;
        }
        integer(d, "input_delay", 0, 8)?;
        integer(d, "game_speed", 1, 6)?;
        boolean(d, "combos")?; // Arcade keeps the Endless-only combo timer off.
        boolean(d, "dedicated_special")?; // Delivered later by player-1 tick masks.
        let processor = integer(d, "processor_type", 1, 6)? as u8;
        let mutators = integer(d, "mutators", 0, 255)? as u8;
        let style = integer(d, "explosion_style", 0, 2)?;
        let hitstop = boolean(d, "hitstop")?;
        let modern = boolean(d, "particles")? && style == 2 && processor >= 2;
        let modern = boolean(d, "screenshake")? && modern;
        let first = array(d, "loadout1", 10)?;
        let second = array(d, "loadout2", 10)?;
        let mods = self.mods.as_mut()?;
        let check = if carry.is_some() {
            mods.bind_mut().network_validate_continuation_level(
                ep as i32,
                level as i32,
                difficulty as i32,
                PackedInt32Array::from(first.as_slice()),
                PackedInt32Array::from(second.as_slice()),
            )
        } else {
            mods.bind_mut().network_validate_level(
                ep as i32,
                level as i32,
                difficulty as i32,
                PackedInt32Array::from(first.as_slice()),
                PackedInt32Array::from(second.as_slice()),
            )
        };
        if !check.get("valid")?.try_to::<bool>().ok()? {
            return None;
        }
        let mut setup = tyrian_sim::setup::load_level(
            std::path::Path::new(data),
            ep,
            0,
            level as usize,
            difficulty,
            loadout(&first),
            seed,
        )
        .ok()?;
        setup.initial_difficulty = Some(initial);
        setup.loadout.cash = cash.0.min(u32::MAX as u64) as u32;
        setup.carry_over = carry;
        setup.second_player_loadout = Some(crate::default_loadout());
        setup.processor_type = processor;
        setup.modes = ModeSetup {
            two_player: true,
            devices: (0, 0),
            initial_difficulty: initial,
            loadout2: Some(loadout(&second)),
            cash,
            mutators,
            ..Default::default()
        };
        mods.bind_mut().apply_to(&mut setup, level);
        let mut sim = if carry.is_some() { Sim::new_network_continuation(setup)? } else { Sim::new(setup) };
        sim.set_bonus_level_current(bonus);
        let mut stars = tyrian_sim::rng::MersenneTwister::new(5489);
        sim.set_starfield(tyrian_sim::world::initialize_starfield(processor, &mut stars));
        sim.set_fx_config(tyrian_sim::fx::FxConfig { hitstop, modern_explosions: modern, events: true });
        sim.set_keep_presented(true);
        Some(sim)
    }

    fn install_network_level(&mut self, sim: Sim, config: &VarDictionary) {
        self.loadout = sim.setup().loadout;
        self.modes = sim.setup().modes;
        self.campaign_initial_difficulty = sim.setup().initial_difficulty;
        self.campaign_carry = sim.setup().carry_over;
        self.processor_type = sim.setup().processor_type;
        self.fx_cfg = sim.world().fx;
        self.fx_on = false;
        self.network_fx_setup = Some((
            hex(config, "seed").expect("validated seed"),
            crate::fx_render::FxOptions {
                particles: boolean(config, "particles").expect("validated particles"),
                style: integer(config, "explosion_style", 0, 2).expect("validated style") as u8,
                hitstop: boolean(config, "hitstop").expect("validated hitstop"),
                shake: boolean(config, "screenshake").expect("validated shake"),
                processor_type: self.processor_type as i32,
                ..Default::default()
            },
        ));
        self.sim = Some(sim);
        self.last_error = GString::new();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strict_unsigned_money_and_carry_bits() {
        assert_eq!(unsigned_hex("ffffffffffffffff"), Some(u64::MAX));
        for bad in ["", "FFFFFFFFFFFFFFFF", "000000000000000g", "-000000000000001"] {
            assert_eq!(unsigned_hex(bad), None);
        }
        let raw = [-1, 4, 5, 6, 1, 3, 2];
        let carry = continuation_carry(&raw).unwrap();
        assert_eq!(carry.players[0].x_friction_ticks, u32::MAX);
        assert_eq!(carry.to_values(), raw);
        for bad in [vec![], vec![0; 6], vec![0; 8], vec![0, 0, 0, 0, 2, 0, 0], vec![0, 0, 0, 0, 0, 256, 0]] {
            assert!(continuation_carry(&bad).is_none());
        }
    }

    #[test]
    fn two_player_cash_thresholds_current_floor_and_wrapping_sum() {
        let cash = |n: u64| format!("{n:016x}");
        assert_eq!(continuation_difficulty(3, 2, &cash(31249), &cash(31250)), Some(3));
        assert_eq!(continuation_difficulty(3, 2, &cash(31250), &cash(31250)), Some(4));
        assert_eq!(continuation_difficulty(8, 2, &cash(0), &cash(0)), Some(8));
        assert_eq!(continuation_difficulty(3, 2, &cash(u64::MAX), &cash(1)), Some(3));
        // Preserve the existing software-float out-of-range conversion too;
        // enormous cash must not silently introduce a new saturation rule.
        assert_eq!(continuation_difficulty(3, 2, &cash(u64::MAX), &cash(0)), Some(3));
        assert_eq!(continuation_difficulty(3, 2, &cash(750_000), &cash(0)), Some(9));
        assert_eq!(continuation_difficulty(2, 2, &cash(0), &cash(0)), None);
        assert_eq!(continuation_difficulty(3, 5, &cash(0), &cash(0)), None);
        assert_eq!(continuation_difficulty(3, i32::MAX, &cash(0), &cash(0)), None);
    }
}

#[godot_api(secondary)]
impl TyrianSim {
    /// Fresh detached preview only. No FX, audio, processor or starfield globals.
    /// The caller must validate rules/content and retain the shop boundary.
    #[func]
    fn prepare_network_level(&mut self, data_dir: GString, config: VarDictionary) -> bool {
        if self.sim.is_some() || self.replay.is_some() || self.recorder.is_some() || self.record_request.is_some() {
            self.last_error = "network_preview_requires_fresh_node".into();
            return false;
        }
        let Some(sim) = self.detached_level(&data_dir.to_string(), &config, None, false) else {
            self.last_error = "invalid_network_preview".into();
            return false;
        };
        self.install_network_level(sim, &config);
        true
    }

    /// Approved network-only later-level adaptation. Initial startup policy is
    /// deliberately separate. Caller must validate committed script/lineage.
    #[func]
    fn prepare_network_continuation(
        &mut self,
        data_dir: GString,
        config: VarDictionary,
        carry: PackedInt32Array,
        bonus_level: bool,
    ) -> bool {
        if self.sim.is_some() || self.replay.is_some() || self.recorder.is_some() || self.record_request.is_some() {
            self.last_error = "network_preview_requires_fresh_node".into();
            return false;
        }
        let Some(carry) = continuation_carry(carry.as_slice()) else {
            self.last_error = "invalid_network_carry".into();
            return false;
        };
        let Some(sim) = self.detached_level(&data_dir.to_string(), &config, Some(carry), bonus_level) else {
            self.last_error = "invalid_network_continuation".into();
            return false;
        };
        self.install_network_level(sim, &config);
        true
    }

    /// Only after startup comparison: initialize private presentation at tick
    /// zero. Never resets simulation, core FX options or any shared renderer.
    #[func]
    fn start_network_presentation(&mut self) -> bool {
        if self.sim.as_ref().is_none_or(|s| s.state().tick != 0) {
            return false;
        }
        let Some((seed, options)) = self.network_fx_setup else { return false };
        if self.network_fx.is_none() {
            let mut render = crate::fx_render::FxRender::new(seed);
            render.options = options;
            self.network_fx = Some(std::rc::Rc::new(std::cell::RefCell::new(render)));
        }
        true
    }
}
