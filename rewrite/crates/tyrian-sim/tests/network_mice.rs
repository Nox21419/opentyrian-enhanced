//! Network-only per-player mouse routing, approved 2026-11-24. Compare against
//! the existing shared mouse path; this is not new independent C evidence.

use std::path::PathBuf;
use tyrian_sim::modes::{ModeSetup, MouseInput};
use tyrian_sim::{
    setup::load_level, GeneratorId, Loadout, PlayerInput, ShieldId, ShipId, SidekickId, Sim, SpecialId, WeaponId,
};

fn make(devices: (u8, u8)) -> Sim {
    let data = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../data");
    let p1 = Loadout {
        ship: ShipId(11),
        front_weapon: WeaponId(1),
        front_power: 1,
        rear_weapon: WeaponId(0),
        rear_power: 1,
        shield: ShieldId(4),
        generator: GeneratorId(2),
        left_sidekick: SidekickId(0),
        right_sidekick: SidekickId(0),
        special: SpecialId(0),
        cash: 0,
    };
    let p2 = Loadout { ship: ShipId(1), rear_weapon: WeaponId(15), ..p1 };
    let mut setup = load_level(&data, 1, 2, 9, 2, p1, 73).expect("network mouse fixtures require game data");
    setup.modes = ModeSetup { two_player: true, devices, loadout2: Some(p2), ..ModeSetup::default() };
    Sim::new(setup)
}

fn assert_same(a: &Sim, b: &Sim, tick: u32) {
    assert_eq!(a.snapshot(), b.snapshot(), "snapshot at tick {tick}");
    assert_eq!(a.frame_record(), b.frame_record(), "frame at tick {tick}");
    assert_eq!(a.mode_record(), b.mode_record(), "co-op mode at tick {tick}");
}

#[test]
fn each_pointing_device_matches_its_existing_shared_mouse_path() {
    for target in 0..2 {
        let devices = if target == 0 { (2, 1) } else { (1, 2) };
        let (mut shared, mut separate) = (make(devices), make(devices));
        for t in 0..1200 {
            let mouse = MouseInput {
                mask: if t % 61 < 43 { 0xf0 } else { 0 },
                dx: (t as i32 * 7).rem_euclid(81) - 40,
                dy: (t as i32 * 11).rem_euclid(81) - 40,
            };
            let mut mice = [MouseInput::default(); 2];
            mice[target] = mouse;
            shared.set_mouse(mouse);
            separate.set_player_mice(Some(mice));
            let analog = [(-13, 9), (7, -11)];
            shared.set_analog(analog);
            separate.set_analog(analog);
            let keys = [PlayerInput(0x1a), PlayerInput(0x65)];
            shared.step(keys);
            separate.step(keys);
            assert_same(&shared, &separate, t);
        }
    }
}

#[test]
fn both_pointing_devices_move_their_own_ship_in_the_same_tick() {
    let mut sim = make((2, 2));
    for _ in 0..200 {
        sim.step([PlayerInput(0); 2]);
    }
    let before = [sim.world().players[0].x, sim.world().players[1].x];
    sim.set_player_mice(Some([MouseInput { mask: 0x40, dx: -8, dy: 0 }, MouseInput { mask: 0, dx: 8, dy: 0 }]));
    for _ in 0..10 {
        sim.step([PlayerInput(0); 2]);
    }
    assert!(sim.world().players[0].x < before[0]);
    assert!(sim.world().players[1].x > before[1]);
}

#[test]
fn existing_mouse_clamp_and_inertia_still_apply_to_both_players() {
    let (mut normal, mut excessive) = (make((2, 2)), make((2, 2)));
    for t in 0..400 {
        let dx = if t % 40 < 20 { -30 } else { 30 };
        let dy = if t % 60 < 30 { 30 } else { -30 };
        normal.set_player_mice(Some([MouseInput { mask: 0x40, dx, dy }; 2]));
        excessive.set_player_mice(Some([MouseInput { mask: 0x40, dx: dx * 10, dy: dy * 10 }; 2]));
        normal.step([PlayerInput(0); 2]);
        excessive.step([PlayerInput(0); 2]);
        assert_same(&normal, &excessive, t);
    }
}

#[test]
fn clearing_override_restores_shared_input_without_a_residual_delta() {
    let (mut shared, mut separate) = (make((1, 2)), make((1, 2)));
    for t in 0..300 {
        let mouse = MouseInput { mask: 0x10, dx: 8, dy: -4 };
        shared.set_mouse(mouse);
        separate.set_mouse(mouse);
        separate.set_player_mice(Some([MouseInput::default(), mouse]));
        if t >= 150 {
            separate.set_player_mice(None);
        }
        shared.step([PlayerInput(0); 2]);
        separate.step([PlayerInput(0); 2]);
        assert_same(&shared, &separate, t);
    }
}

#[test]
fn linked_player_two_keeps_existing_gun_rotation_and_unlink_behavior() {
    let (mut shared, mut separate) = (make((1, 2)), make((1, 2)));
    let mut linked = false;
    for t in 0..1000 {
        let w = shared.world();
        let mut mouse = MouseInput::default();
        if linked {
            mouse.mask = if t % 80 < 60 { 0x10 } else { 0 };
            mouse.dx = if t % 40 < 20 { 8 } else { -8 };
            mouse.dy = if t % 60 < 30 { 8 } else { -8 };
        } else {
            mouse.dx = ((w.players[0].x - w.players[1].x) * 4).clamp(-30, 30);
            mouse.dy = ((w.players[0].y - w.players[1].y) * 4).clamp(-30, 30);
        }
        shared.set_mouse(mouse);
        separate.set_player_mice(Some([MouseInput::default(), mouse]));
        let keys = [PlayerInput(if t % 200 == 199 { 0x40 } else { 0 }), PlayerInput(0)];
        shared.step(keys);
        separate.step(keys);
        assert_same(&shared, &separate, t);
        linked |= shared.world().mode.two_player_linked;
    }
    assert!(linked, "fixture must exercise linked movement");
}
