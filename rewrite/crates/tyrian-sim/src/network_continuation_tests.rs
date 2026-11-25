use super::*;
use crate::modes::{ModeSetup, MouseInput};
use std::path::PathBuf;

fn setup(episode: u8) -> LevelSetup {
    let data = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../data");
    let first = Loadout {
        ship: ShipId(11),
        front_weapon: WeaponId(1),
        front_power: 1,
        rear_weapon: WeaponId(0),
        rear_power: 3,
        shield: ShieldId(4),
        generator: GeneratorId(2),
        left_sidekick: SidekickId(0),
        right_sidekick: SidekickId(0),
        special: SpecialId(1),
        cash: 1000,
    };
    let second = Loadout { ship: ShipId(1), rear_weapon: WeaponId(15), front_power: 3, rear_power: 1, ..first };
    let mut setup = setup::load_level(&data, episode, 0, 1, 3, first, 73).unwrap();
    setup.initial_difficulty = Some(2);
    setup.second_player_loadout = Some(first);
    setup.carry_over = Some(LevelCarry {
        players: [
            PlayerCarry { x_friction_ticks: 3, y_friction_ticks: 4, ..Default::default() },
            PlayerCarry { x_friction_ticks: 5, y_friction_ticks: 6, sidekick_level: 101, sidekick_series: 0 },
        ],
        special_fire_held: true,
    });
    setup.modes = ModeSetup {
        two_player: true,
        loadout2: Some(second),
        cash: (1000, 2000),
        initial_difficulty: 2,
        devices: (0, 0),
        ..Default::default()
    };
    setup
}

fn input(sim: &mut Sim, tick: i32) {
    sim.set_player_mice(Some([
        MouseInput { mask: 16, dx: if tick % 20 < 10 { 5 } else { -5 }, dy: 0 },
        MouseInput { mask: 16, dx: 0, dy: if tick % 20 < 10 { -5 } else { 5 } },
    ]));
    sim.set_new_key(false);
    sim.step([PlayerInput(0), PlayerInput(0)]);
}

#[test]
fn ordinary_constructor_equivalence_when_no_correction_is_needed() {
    for ep in [1, 4, 5] {
        let setup = setup(ep);
        let mut ordinary = Sim::new(setup.clone());
        let mut network = Sim::new_network_continuation(setup).unwrap();
        assert_eq!(ordinary.network_diagnostic_bytes(), network.network_diagnostic_bytes());
        for tick in 0..64 {
            input(&mut ordinary, tick);
            input(&mut network, tick);
            assert_eq!(ordinary.snapshot(), network.snapshot(), "episode {ep}, tick {tick}");
            assert_eq!(ordinary.world.rng.state(), network.world.rng.state());
            assert_eq!(ordinary.world.mt.state_hash(), network.world.mt.state_hash());
        }
        assert_eq!(ordinary.network_diagnostic_bytes(), network.network_diagnostic_bytes());
    }
}

#[test]
fn full_cash_lives_and_sidekick_carry_exist_before_first_tick_without_rng_draws() {
    let mut setup = setup(1);
    setup.modes.cash = (u64::MAX, 1 << 40);
    setup.loadout.rear_power = 0;
    setup.modes.loadout2.as_mut().unwrap().front_power = 0;
    let carry = setup.carry_over.as_mut().unwrap();
    carry.players[0].x_friction_ticks = u32::MAX;
    carry.players[1].sidekick_level = 3;
    carry.players[1].sidekick_series = 2;
    let ordinary = Sim::new(setup.clone());
    let network = Sim::new_network_continuation(setup.clone()).unwrap();
    assert_eq!(network.state.tick, 0);
    assert_eq!(network.world.players[0].cash, u64::MAX);
    assert_eq!(network.world.level_stats.credits_start, u64::MAX);
    assert_eq!(network.world.players[1].cash, 1 << 40);
    assert_eq!(network.world.players[0].items.weapon[1].power, 0);
    assert_eq!(network.world.players[1].items.weapon[0].power, 0);
    assert_eq!(LevelCarry::from_sim(&network), setup.carry_over.unwrap());
    assert_eq!(network.world.rng.state(), ordinary.world.rng.state());
    assert_eq!(network.world.mt.state_hash(), ordinary.world.mt.state_hash());
    assert_eq!(ordinary.world.players[0].cash, 1000);
    assert_eq!(ordinary.world.players[1].items.sidekick_level, 101);
    let another_ordinary = Sim::new(setup);
    assert_eq!(ordinary.network_diagnostic_bytes(), another_ordinary.network_diagnostic_bytes());
}

#[test]
fn independent_carried_peers_match_ticks_and_generators() {
    let mut setup = setup(4);
    setup.modes.cash = (1 << 63, u64::MAX);
    setup.carry_over.as_mut().unwrap().players[1].sidekick_level = 2;
    setup.carry_over.as_mut().unwrap().players[1].sidekick_series = 1;
    let mut first = Sim::new_network_continuation(setup.clone()).unwrap();
    let mut second = Sim::new_network_continuation(setup).unwrap();
    for tick in 0..128 {
        input(&mut first, tick);
        input(&mut second, tick);
        assert_eq!(first.snapshot(), second.snapshot());
        assert_eq!(first.world.rng.state(), second.world.rng.state());
        assert_eq!(first.world.mt.state_hash(), second.world.mt.state_hash());
    }
    assert_eq!(first.network_diagnostic_bytes(), second.network_diagnostic_bytes());
}

#[test]
fn unsupported_profiles_and_missing_carry_are_rejected() {
    let mut missing = setup(1);
    missing.carry_over = None;
    assert!(Sim::new_network_continuation(missing).is_none());
    for profile in 0..4 {
        let mut setup = setup(1);
        match profile {
            0 => setup.modes.two_player = false,
            1 => setup.modes.galaga = true,
            2 => setup.modes.one_player_action = true,
            _ => setup.modes.endless_lives = Some([3, 3]),
        }
        assert!(Sim::new_network_continuation(setup).is_none());
    }
}
