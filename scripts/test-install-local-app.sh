#!/bin/bash
# Isolated failure-path tests for scripts/install-local-app.sh's swap/restore
# logic. Everything runs in temporary directories and the two probe functions
# (verification + running-process detection) are faked, so the real installed
# app and the real code-signing identity are never touched.
#
# Run with: bash scripts/test-install-local-app.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=install-lib.sh
source "$SCRIPT_DIR/install-lib.sh"

BUNDLE_ID="com.ntstudio.MacActionScheduler"
EXECUTABLE_NAME="MacActionScheduler"

PASS=0
FAIL=0

# --- Faked probes (overrides) ----------------------------------------------
RUNNING=0
VERIFY_CALLS=0
VERIFY_FAIL_ON_CALL=0

mas_is_installed_app_running() {
    [[ "$RUNNING" == "1" ]]
}

mas_verify_app() {
    VERIFY_CALLS=$((VERIFY_CALLS + 1))
    if [[ "$VERIFY_FAIL_ON_CALL" != "0" && "$VERIFY_CALLS" -eq "$VERIFY_FAIL_ON_CALL" ]]; then
        return 1
    fi
    return 0
}

reset_probes() {
    RUNNING=0
    VERIFY_CALLS=0
    VERIFY_FAIL_ON_CALL=0
}

# --- Assertions -------------------------------------------------------------
ok() {
    PASS=$((PASS + 1))
    echo "PASS: $1"
}

bad() {
    FAIL=$((FAIL + 1))
    echo "FAIL: $1" >&2
}

check_eq() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        ok "$1"
    else
        bad "$1 (expected '$2', got '$3')"
    fi
}

# --- Fixtures ---------------------------------------------------------------
make_fake_app() {
    local app_path="$1"
    local bundle_id="$2"
    local marker="$3"
    mkdir -p "$app_path/Contents/MacOS"
    cat > "$app_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
</dict>
</plist>
PLIST
    printf '#!/bin/bash\nexit 0\n' > "$app_path/Contents/MacOS/$EXECUTABLE_NAME"
    chmod +x "$app_path/Contents/MacOS/$EXECUTABLE_NAME"
    printf '%s' "$marker" > "$app_path/Contents/MacOS/.marker"
}

marker_of() {
    cat "$1/Contents/MacOS/.marker" 2>/dev/null
}

# Assert the sandbox contains no leftover staging/backup directories.
assert_no_leftovers() {
    local dir="$1"
    local leftover=""
    local f
    for f in "$dir"/.mac-action-scheduler.*; do
        if [[ -e "$f" ]]; then
            leftover="$f"
            break
        fi
    done
    if [[ -n "$leftover" ]]; then
        bad "leftover staging/backup directory: $leftover"
    else
        ok "no leftover staging/backup directories"
    fi
}

# --- Scenarios --------------------------------------------------------------
run_scenario() {
    local name="$1"
    local fn="$2"
    local sandbox source_app target_dir target
    sandbox="$(mktemp -d "${TMPDIR:-/tmp}/mas-install-test.XXXXXX")"
    source_app="$sandbox/Source.app"
    target_dir="$sandbox/Applications"
    target="$target_dir/Mac Action Scheduler.app"

    echo ""
    echo "=== Scenario: $name ==="
    make_fake_app "$source_app" "$BUNDLE_ID" "NEW"
    "$fn" "$sandbox" "$source_app" "$target_dir" "$target"

    rm -rf "$sandbox"
}

scenario_fresh_install() {
    local source_app="$2" target_dir="$3" target="$4"
    reset_probes
    mas_install "$source_app" "$target_dir" "$BUNDLE_ID" "$EXECUTABLE_NAME"
    local rc=$?
    check_eq "fresh install exits 0" "0" "$rc"
    check_eq "fresh install places NEW bundle" "NEW" "$(marker_of "$target")"
    assert_no_leftovers "$target_dir"
}

scenario_replace_existing() {
    local source_app="$2" target_dir="$3" target="$4"
    reset_probes
    make_fake_app "$target" "$BUNDLE_ID" "OLD"
    mas_install "$source_app" "$target_dir" "$BUNDLE_ID" "$EXECUTABLE_NAME"
    local rc=$?
    check_eq "replace exits 0" "0" "$rc"
    check_eq "replace installs NEW bundle" "NEW" "$(marker_of "$target")"
    assert_no_leftovers "$target_dir"
}

scenario_final_verify_failure_restores() {
    local source_app="$2" target_dir="$3" target="$4"
    reset_probes
    make_fake_app "$target" "$BUNDLE_ID" "OLD"
    VERIFY_FAIL_ON_CALL=2   # fail the final (target) verification only
    mas_install "$source_app" "$target_dir" "$BUNDLE_ID" "$EXECUTABLE_NAME"
    local rc=$?
    check_eq "final-verify failure exits 1" "1" "$rc"
    check_eq "previous app restored" "OLD" "$(marker_of "$target")"
    assert_no_leftovers "$target_dir"
}

scenario_running_refused_before_swap() {
    local source_app="$2" target_dir="$3" target="$4"
    reset_probes
    make_fake_app "$target" "$BUNDLE_ID" "OLD"
    RUNNING=1
    mas_install "$source_app" "$target_dir" "$BUNDLE_ID" "$EXECUTABLE_NAME"
    local rc=$?
    check_eq "running app refused with exit 2" "2" "$rc"
    check_eq "running app leaves existing bundle intact" "OLD" "$(marker_of "$target")"
    assert_no_leftovers "$target_dir"
}

scenario_first_install_verify_failure_removes() {
    local source_app="$2" target_dir="$3" target="$4"
    reset_probes
    VERIFY_FAIL_ON_CALL=2   # fail the final (target) verification
    mas_install "$source_app" "$target_dir" "$BUNDLE_ID" "$EXECUTABLE_NAME"
    local rc=$?
    check_eq "first-install verify failure exits 1" "1" "$rc"
    if [[ -e "$target" ]]; then
        bad "unverified bundle removed on first-install failure"
    else
        ok "unverified bundle removed on first-install failure"
    fi
    assert_no_leftovers "$target_dir"
}

# --- Main -------------------------------------------------------------------
main() {
    run_scenario "fresh install" scenario_fresh_install
    run_scenario "replace existing app" scenario_replace_existing
    run_scenario "final verification failure restores previous app" scenario_final_verify_failure_restores
    run_scenario "running app refused before swap" scenario_running_refused_before_swap
    run_scenario "first install final verification failure removes unverified bundle" scenario_first_install_verify_failure_removes

    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    [[ "$FAIL" -eq 0 ]]
}

main
