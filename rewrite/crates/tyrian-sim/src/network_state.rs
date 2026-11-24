//! Conservative diagnostic state stream, separate from frozen replay hashes.
//! Rust's derived Hash traversal is build-specific, not a stable save/wire format.
//! Only identical source/compiler identities on little-endian 64-bit targets may
//! compare it. Includes observers: compare only at the same consumption boundary.
use std::hash::{Hash, Hasher};

use crate::Sim;

const MAX_BYTES: usize = 16 * 1024 * 1024;

#[derive(Default)]
struct StateWriter {
    bytes: Vec<u8>,
    overflow: bool,
}

impl Hasher for StateWriter {
    // Hash traversal only writes. No caller uses this collector as a u64 hash.
    fn finish(&self) -> u64 {
        0
    }

    fn write(&mut self, bytes: &[u8]) {
        if self.overflow || bytes.len() > MAX_BYTES.saturating_sub(self.bytes.len()) {
            self.overflow = true;
            return;
        }
        self.bytes.extend_from_slice(bytes);
    }

    fn write_usize(&mut self, value: usize) {
        self.write(&(value as u64).to_le_bytes());
    }

    fn write_isize(&mut self, value: isize) {
        self.write(&(value as i64).to_le_bytes());
    }
}

impl Sim {
    /// Full retained core object graph, including input/RNG/table/event state.
    /// Intentionally includes observer state, so this is a conservative diagnostic
    /// fingerprint, not yet a gameplay-only live desync detector or restore format.
    /// Excludes presented copies/keep_presented and replay-only bottom positions.
    /// Does not step, consume queues, mutate RNG or change legacy snapshot bytes.
    pub fn network_diagnostic_bytes(&self) -> Option<Vec<u8>> {
        // Hash::hash_slice may use primitive memory order. Restrict comparisons
        // to the actual supported Android/desktop target representation.
        if !cfg!(all(target_endian = "little", target_pointer_width = "64")) {
            return None;
        }
        let mut writer = StateWriter::default();
        writer.write(b"OT2-DIAGNOSTIC-STATE\x01");
        self.setup.hash(&mut writer);
        self.state.hash(&mut writer);
        self.last_mask.hash(&mut writer);
        self.world.hash(&mut writer);
        (!writer.overflow).then_some(writer.bytes)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::modes::MouseInput;
    use crate::{setup::load_level, Loadout, PlayerInput};
    use std::path::PathBuf;

    fn sim() -> Sim {
        let data = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../data");
        let loadout = Loadout {
            ship: crate::ShipId(11),
            front_weapon: crate::WeaponId(1),
            front_power: 1,
            rear_weapon: crate::WeaponId(0),
            rear_power: 1,
            shield: crate::ShieldId(4),
            generator: crate::GeneratorId(2),
            left_sidekick: crate::SidekickId(0),
            right_sidekick: crate::SidekickId(0),
            special: crate::SpecialId(0),
            cash: 0,
        };
        let setup = load_level(&data, 1, 2, 9, 3, loadout, 73).unwrap();
        Sim::new(setup)
    }

    #[test]
    fn omitted_legacy_fields_are_covered() {
        for edit in 0..5 {
            let a = sim();
            let mut b = sim();
            match edit {
                0 => b.world.mode.devices[0] = 2,
                1 => b.world.players[0].x_friction_ticks += 1,
                2 => b.world.enemy[0].eshotwait[0] += 1,
                3 => b.world.fx.hitstop = true,
                _ => b.set_player_mice(Some([MouseInput::default(); 2])),
            }
            assert_eq!(a.snapshot(), b.snapshot(), "fixture must expose a legacy omission");
            assert_ne!(a.network_diagnostic_bytes(), b.network_diagnostic_bytes());
        }
    }

    #[test]
    fn repeated_serialization_does_not_change_simulation_or_legacy_replay_state() {
        let mut a = sim();
        let mut b = sim();
        a.set_keep_presented(true);
        for tick in 0..120 {
            let before = a.snapshot();
            let bytes = a.network_diagnostic_bytes().unwrap();
            assert!(!bytes.is_empty() && bytes.len() < MAX_BYTES);
            assert_eq!(bytes, a.network_diagnostic_bytes().unwrap());
            assert_eq!(before, a.snapshot());
            let input = [PlayerInput(if tick % 7 == 0 { 16 } else { 0 }); 2];
            a.step(input);
            b.step(input);
            assert_eq!(a.frame_record(), b.frame_record());
            assert_eq!(a.snapshot(), b.snapshot());
            assert_eq!(a.network_diagnostic_bytes(), b.network_diagnostic_bytes());
        }
    }

    #[test]
    fn writer_enforces_size_limit_and_fixed_pointer_integer_encoding() {
        let mut writer = StateWriter::default();
        writer.write_usize(1);
        writer.write_isize(-2);
        assert_eq!(&writer.bytes[..8], &1u64.to_le_bytes());
        assert_eq!(&writer.bytes[8..], &(-2i64).to_le_bytes());
        writer.write(&vec![0; MAX_BYTES]);
        assert!(writer.overflow);
        assert_eq!(writer.bytes.len(), 16);
    }
}
