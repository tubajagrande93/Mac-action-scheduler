#!/bin/bash
# Reusable installer core for Mac Action Scheduler.
#
# Shared by scripts/install-local-app.sh (the real installer) and
# scripts/test-install-local-app.sh (isolated failure-path tests). The probe
# functions below (mas_verify_app, mas_is_installed_app_running) are overridden
# by the test harness so the swap/restore logic can be exercised without real
# code signing or a real running process.
#
# All destructive work happens against paths passed into mas_install, never
# hard-coded locations, so tests can run entirely inside temporary directories.

# Global state inspected by the EXIT trap. Kept global (not local) so the trap
# can see it after the install function returns.
MAS_STAGING_DIR=""
MAS_BACKUP_DIR=""
MAS_TARGET=""
MAS_BACKED_UP=0
MAS_SWAPPED=0
MAS_FINALIZED=0

# Verifies an .app bundle. The real implementation uses codesign; the test
# harness replaces it to simulate verification failures.
mas_verify_app() {
    codesign --verify --deep --strict --verbose=2 "$1"
}

# Exit 0 when the app executable at "$1" is currently running. The test
# harness replaces it to simulate a running process.
mas_is_installed_app_running() {
    [[ -x "$1" ]] && pgrep -f "$1" >/dev/null 2>&1
}

mas_bundle_identifier() {
    /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist"
}

# Refuses (exit 2) while the installed app is running.
mas_refuse_if_running() {
    local installed_executable="$1"
    if mas_is_installed_app_running "$installed_executable"; then
        echo "ERROR: The installed Mac Action Scheduler is currently running." >&2
        echo "A scheduled click may be pending; refusing to overwrite it." >&2
        echo "Quit the app (or wait for any active job to finish) and try again." >&2
        return 2
    fi
    return 0
}

# Print an error, run cleanup (restoring the previous app if needed), and
# return the supplied exit code.
mas_abort() {
    local code="$1"
    local message="$2"
    echo "ERROR: $message" >&2
    mas_cleanup
    return "$code"
}

# Restores the previous app if the install was interrupted or failed after the
# target began being modified, then removes temporary staging/backup
# directories. Idempotent: safe to run on the failure path and again as the
# EXIT trap. The backup directory is deleted only once it is no longer needed
# (i.e. the new bundle is in place and has passed final verification).
mas_cleanup() {
    if [[ "$MAS_FINALIZED" == "0" && "$MAS_BACKED_UP" == "1" ]]; then
        # Old app was moved aside but never replaced+verified: restore it.
        [[ -n "$MAS_TARGET" ]] && rm -rf "$MAS_TARGET"
        if [[ -n "$MAS_BACKUP_DIR" && -d "$MAS_BACKUP_DIR/Mac Action Scheduler.app" ]]; then
            mv "$MAS_BACKUP_DIR/Mac Action Scheduler.app" "$MAS_TARGET"
            echo "Restored previous Mac Action Scheduler after failed/interrupted install." >&2
        fi
    elif [[ "$MAS_FINALIZED" == "0" && "$MAS_SWAPPED" == "1" ]]; then
        # First install (no previous version) that failed verification:
        # remove the unverified bundle.
        [[ -n "$MAS_TARGET" ]] && rm -rf "$MAS_TARGET"
    fi
    MAS_BACKED_UP=0
    MAS_SWAPPED=0
    MAS_FINALIZED=0
    [[ -n "$MAS_STAGING_DIR" ]] && rm -rf "$MAS_STAGING_DIR"
    [[ -n "$MAS_BACKUP_DIR" ]] && rm -rf "$MAS_BACKUP_DIR"
    MAS_STAGING_DIR=""
    MAS_BACKUP_DIR=""
    MAS_TARGET=""
}

# Stages SOURCE_APP, swaps it into TARGET_DIR, verifies the final bundle, and
# restores the previous version on any failure (including interrupted installs).
# The backup is deleted only after the final bundle passes verification.
#
# Returns 0 on success, 2 when the installed app is running, 1 on other failures.
mas_install() {
    local source_app="$1"
    local target_dir="$2"
    local bundle_id="$3"
    local executable_name="$4"

    MAS_TARGET="$target_dir/Mac Action Scheduler.app"
    local installed_executable="$MAS_TARGET/Contents/MacOS/$executable_name"

    MAS_STAGING_DIR=""
    MAS_BACKUP_DIR=""
    MAS_BACKED_UP=0
    MAS_SWAPPED=0
    MAS_FINALIZED=0

    if [[ ! -d "$source_app" ]]; then
        mas_abort 1 "Source app not found: $source_app"
        return
    fi

    if ! mkdir -p "$target_dir"; then
        mas_abort 1 "Could not create target directory: $target_dir"
        return
    fi

    if ! MAS_STAGING_DIR="$(mktemp -d "$target_dir/.mac-action-scheduler.staging.XXXXXX")"; then
        mas_abort 1 "Could not create staging directory"
        return
    fi

    # Copy the freshly built bundle into a temporary sibling and validate it in
    # place, so a failed copy or a bad signature never destroys the target.
    if ! ditto "$source_app" "$MAS_STAGING_DIR/Mac Action Scheduler.app"; then
        mas_abort 1 "Could not stage the bundle"
        return
    fi

    if ! mas_verify_app "$MAS_STAGING_DIR/Mac Action Scheduler.app"; then
        mas_abort 1 "Staged bundle failed verification"
        return
    fi

    local staged_bundle_id
    staged_bundle_id="$(mas_bundle_identifier "$MAS_STAGING_DIR/Mac Action Scheduler.app")"
    if [[ "$staged_bundle_id" != "$bundle_id" ]]; then
        mas_abort 1 "Staged bundle has unexpected bundle ID: $staged_bundle_id"
        return
    fi

    # Re-check immediately before the swap: the build takes time, and the app
    # may have been launched in the meantime.
    mas_refuse_if_running "$installed_executable"
    local rc=$?
    if [[ "$rc" -ne 0 ]]; then
        mas_cleanup
        return "$rc"
    fi

    # Preserve the previous version until the replacement is fully in place.
    if [[ -d "$MAS_TARGET" ]]; then
        if ! MAS_BACKUP_DIR="$(mktemp -d "$target_dir/.mac-action-scheduler.backup.XXXXXX")"; then
            mas_abort 1 "Could not create backup directory"
            return
        fi
        if ! mv "$MAS_TARGET" "$MAS_BACKUP_DIR/Mac Action Scheduler.app"; then
            mas_abort 1 "Could not move the existing app aside"
            return
        fi
        MAS_BACKED_UP=1
    fi

    if ! mv "$MAS_STAGING_DIR/Mac Action Scheduler.app" "$MAS_TARGET"; then
        mas_abort 1 "Could not move the staged bundle into place"
        return
    fi
    MAS_SWAPPED=1

    # Final verification of the installed bundle. On failure, mas_abort ->
    # mas_cleanup restores the previous version instead of deleting the backup.
    if ! mas_verify_app "$MAS_TARGET"; then
        mas_abort 1 "Final verification of the installed bundle failed; restoring previous version"
        return
    fi

    # Only now is the backup safe to delete: the new bundle is in place and
    # has passed verification.
    MAS_FINALIZED=1
    [[ -n "$MAS_BACKUP_DIR" ]] && rm -rf "$MAS_BACKUP_DIR"
    MAS_BACKUP_DIR=""
    [[ -n "$MAS_STAGING_DIR" ]] && rm -rf "$MAS_STAGING_DIR"
    MAS_STAGING_DIR=""

    return 0
}
