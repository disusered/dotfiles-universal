use assert_cmd::Command;
use predicates::prelude::*;
use std::fs;
use std::os::unix::fs::PermissionsExt;

#[test]
fn tmux_wrapper_bridges_when_parent_is_abtop() {
    let clients = r#"[{"address":"0xabc","pid":42}]"#;
    let temp_dir =
        std::env::temp_dir().join(format!("cfg-tmux-wrapper-test-{}", std::process::id()));
    fs::create_dir_all(&temp_dir).unwrap();
    let fake_abtop = temp_dir.join("abtop");
    fs::write(
        &fake_abtop,
        format!(
            "#!/usr/bin/env sh\n{}/tmux-wrapper.sh \"$@\"\n",
            env!("CARGO_MANIFEST_DIR")
        ),
    )
    .unwrap();
    let mut permissions = fs::metadata(&fake_abtop).unwrap().permissions();
    permissions.set_mode(0o755);
    fs::set_permissions(&fake_abtop, permissions).unwrap();

    Command::new(fake_abtop)
        .env("CFG_TMUX_BRIDGE_CLIENTS_JSON", clients)
        .env("CFG_TMUX_BRIDGE_CFG_BIN", env!("CARGO_BIN_EXE_cfg"))
        .env_remove("CFG_TMUX_BRIDGE")
        .args(["list-panes", "-a", "-F", "panes"])
        .assert()
        .success()
        .stdout(predicate::str::contains("42 cfg-hypr-0xabc:1.1"));

    let _ = fs::remove_dir_all(temp_dir);
}
