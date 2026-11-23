use std::path::{Path, PathBuf};
use tyrian_formats::episode::EpisodeScript;
use tyrian_mods::{episode_items, json, ModFolder, ModSet, ResolvedMods, Severity};
use tyrian_sim::{
    shop::{AlwaysAvailable, ShopKey, ShopSession},
    world::{Items, WeaponSlot},
    WeaponId,
};

fn root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..").canonicalize().unwrap()
}
fn set() -> ModSet {
    let mut set = ModSet::load_from(&root().join("data"), &root().join("rewrite/mods"));
    for folder in ["alien_ship_pack", "bio_ships_pack", "alien_weapon_pack", "bio_weapons_pack", "elements_weapon_pack"]
    {
        assert!(set.set_enabled(folder, true));
    }
    set
}
fn resolve(set: &ModSet, ep: u8) -> ResolvedMods {
    let (_, items) = episode_items(&root().join("data"), ep).unwrap();
    let r = set.resolve(ep, &items);
    assert_eq!(r.diagnostics.count(Severity::Error), 0, "{:?}", r.diagnostics);
    r
}
fn names(r: &ResolvedMods, section: u16) -> Vec<String> {
    let t = r.tables.as_ref().unwrap();
    r.shop_at(section)["weapons"].iter().map(|id| t.ports[*id as usize].name.text()).collect()
}

#[test]
fn campaign_milestones_unlock_the_shipped_weapons_in_stages() {
    let set = set();
    let cases = [
        (1, 2, 3),
        (1, 4, 3),
        (1, 15, 3),
        (1, 17, 3),
        (1, 9, 6),
        (1, 40, 6),
        (2, 1, 9),
        (2, 3, 9),
        (2, 7, 10),
        (3, 1, 12),
        (3, 3, 12),
        (3, 7, 14),
        (4, 1, 16),
        (4, 51, 16),
        (5, 1, 17),
        (5, 9, 18),
        (5, 17, 18),
    ];
    for (ep, section, count) in cases {
        let r = resolve(&set, ep);
        let available = names(&r, section);
        assert_eq!(available.len(), count, "ep{ep} section {section}: {available:?}");
        assert_eq!(
            r.tables.as_ref().unwrap().ports.iter().skip(61).filter(|w| !w.name.text().is_empty()).count(),
            18,
            "availability never removes weapon definitions"
        );
        assert_eq!(r.shop_at(section)["ships"].len(), 14, "weapon gating must not change ships");
    }
    let early = names(&resolve(&set, 1), 2);
    assert_eq!(early, vec!["Hazudra Crescent Fan", "Zica Plasma Halo", "Spore Burst"]);
    assert!(!names(&resolve(&set, 4), 51).contains(&"Zica Thermal Lance".to_owned()));
    assert!(!names(&resolve(&set, 5), 1).contains(&"Acid Rain".to_owned()));
}

#[test]
fn every_explicit_unlock_section_is_an_actual_shop_in_the_original_script() {
    let set = set();
    let r = resolve(&set, 1);
    for u in r.weapon_unlocks.values() {
        let bytes = std::fs::read(root().join(format!("data/levels{}.dat", u.episode))).unwrap();
        let script = EpisodeScript::parse(&bytes).unwrap();
        let sections = script.sections();
        for n in &u.sections {
            assert!(
                sections.iter().any(|s| s.number == *n as usize && !s.shops.is_empty()),
                "ep{} section {} is not a shop",
                u.episode,
                n
            );
        }
    }
}

#[test]
fn locked_equipped_weapons_survive_full_early_shop_and_stay_upgradable() {
    let r = resolve(&set(), 1);
    let t = r.tables.as_ref().unwrap();
    let id = t.ports.iter().position(|w| w.name.text() == "Zica Thermal Lance").unwrap() as u8;
    let gated = r.shop_at(2);
    assert!(!gated["weapons_front"].contains(&id));
    let always = AlwaysAvailable {
        front_weapons: gated["weapons_front"].clone(),
        rear_weapons: gated["weapons_rear"].clone(),
        ..Default::default()
    };
    let items = Items {
        weapon: [WeaponSlot { id: WeaponId(id), power: 7 }, WeaponSlot { id: WeaponId(0), power: 1 }],
        ..Default::default()
    };
    let native = vec![vec![], (1..=10).collect()];
    let mut session = ShopSession::with_always_available(t, items, 100000, &native, 1, &always);
    assert_eq!(session.items.weapon[0], items.weapon[0]);
    assert!(session.item_avail[1].contains(&id));
    assert_eq!(session.item_avail[1].iter().filter(|x| **x == id).count(), 1);
    assert!(session.item_avail[1].len() > 10);
    session.click_row(t, 4);
    session.click_row(t, 4);
    session.click_row(t, 3);
    session.click_row(t, 3);
    let row = session.item_avail[1].iter().position(|x| *x == id).unwrap() as u8 + 2;
    session.click_row(t, row);
    let before = session.items.weapon[0].power;
    session.key(t, ShopKey::Right);
    assert_eq!(session.items.weapon[0].power, before + 1);
}

#[test]
fn gated_mods_alone_unlock_in_their_correct_bays_and_do_not_depend_on_slot_order() {
    let mut set = set();
    for folder in ["alien_ship_pack", "bio_ships_pack", "alien_weapon_pack", "bio_weapons_pack"] {
        set.set_enabled(folder, false);
    }
    let r = resolve(&set, 1);
    assert!(names(&r, 2).is_empty());
    assert_eq!(names(&r, 9), vec!["Flame Lance"]);
    let r = resolve(&set, 5);
    let stock = r.shop_at(17);
    let t = r.tables.as_ref().unwrap();
    assert_eq!(
        stock["weapons_front"].iter().map(|id| t.ports[*id as usize].name.text()).collect::<Vec<_>>(),
        vec!["Flame Lance", "Frost Shard", "Arc Caster"]
    );
    assert_eq!(stock["weapons_rear"].len(), 3);
}

#[test]
fn each_weapon_pack_alone_keeps_all_six_guns_and_correct_initial_stock() {
    for (pack, early) in [("alien_weapon_pack", 2), ("bio_weapons_pack", 1), ("elements_weapon_pack", 0)] {
        let mut set = set();
        let folders: Vec<_> = set.folders.iter().map(|f| f.folder.clone()).collect();
        for folder in folders {
            set.set_enabled(&folder, folder == pack);
        }
        assert_eq!(names(&resolve(&set, 1), 2).len(), early, "{pack}");
        let final_shop = resolve(&set, 5).shop_at(17);
        assert_eq!(final_shop["weapons"].len(), 6, "{pack}");
        assert_eq!(final_shop["weapons_front"].len(), 3, "{pack}");
        assert_eq!(final_shop["weapons_rear"].len(), 3, "{pack}");
    }
}

#[test]
fn malformed_unlocks_fail_closed_and_legacy_always_available_still_works() {
    let mut set = set();
    set.folders.clear();
    let bad = [
        "null",
        "[]",
        "{}",
        r#"{"episode":0}"#,
        r#"{"episode":6}"#,
        r#"{"episode":1.5}"#,
        r#"{"episode":"2"}"#,
        r#"{"episode":2,"section":4}"#,
        r#"{"episode":2,"sections":[]}"#,
        r#"{"episode":2,"sections":[0]}"#,
        r#"{"episode":2,"sections":[65536]}"#,
        r#"{"episode":2,"sections":[4.5]}"#,
        r#"{"episode":2,"sections":[4,4]}"#,
        r#"{"episode":2,"sections":"4"}"#,
    ];
    for raw in bad {
        set.folders=vec![ModFolder {folder:"test".into(),enabled:true,root:Some(json::parse(&format!(r#"{{"format_version":1,"weapons":[{{"name":"Locked","base":"Pulse-Cannon","shop_unlock":{raw}}}]}}"#)).unwrap()),..Default::default()}];
        let (_, items) = episode_items(&root().join("data"), 1).unwrap();
        let r = set.resolve(1, &items);
        assert!(r.diagnostics.count(Severity::Error) > 0, "accepted {raw}");
        assert!(r.shop["weapons"].is_empty());
    }
    for fields in [r#""always_available":true"#, r#""always_available":false,"shop_unlock":{"episode":1}"#] {
        set.folders[0].root = Some(
            json::parse(&format!(
                r#"{{"format_version":1,"weapons":[{{"name":"Legacy","base":"Pulse-Cannon",{fields}}}]}}"#
            ))
            .unwrap(),
        );
        assert_eq!(names(&resolve(&set, 1), 2), vec!["Legacy"]);
    }
    set.folders[0].root=Some(json::parse(r#"{"format_version":1,"weapons":[{"name":"Conflict","base":"Pulse-Cannon","always_available":true,"shop_unlock":{"episode":2}}]}"#).unwrap());
    let (_, items) = episode_items(&root().join("data"), 1).unwrap();
    let r = set.resolve(1, &items);
    assert!(r.diagnostics.count(Severity::Error) > 0);
    assert!(r.shop["weapons"].is_empty());
}
