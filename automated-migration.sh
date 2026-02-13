#!/bin/bash
# Automated Migration Script with Guardrails
# Version: 2.2.0
# This script automates as much as safely possible

set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/migration-config-v2.sh" ]; then
    source "${SCRIPT_DIR}/migration-config-v2.sh"
    init_config "$@"
else
    echo "ERROR: migration-config-v2.sh not found!"
    exit 1
fi

# Temp admin credentials
TEMP_ADMIN_USER="tempadmin"
TEMP_ADMIN_FULLNAME="Temporary Migration Admin"

log_info "═══════════════════════════════════════════════════════════════"
log_info "  AUTOMATED MIGRATION SCRIPT v2.2"
log_info "  Maximum automation with safety guardrails"
log_info "═══════════════════════════════════════════════════════════════"

print_config_summary

# ═══════════════════════════════════════════════════════════════
# PHASE 0: CRITICAL SAFETY CHECKS
# ═══════════════════════════════════════════════════════════════

log_info "═══════════════════════════════════════════════════════════════"
log_info "PHASE 0: Critical Safety Checks"
log_info "═══════════════════════════════════════════════════════════════"

# Check 1: Running as target user (not root, not temp admin)
CURRENT_USER=$(whoami)
if [ "${CURRENT_USER}" != "${OLD_USERNAME}" ]; then
    log_error "Must run as user: ${OLD_USERNAME}"
    log_error "Current user: ${CURRENT_USER}"
    exit 1
fi
log_success "Running as correct user: ${CURRENT_USER}"

# Check 2: Check if temp admin already exists
if id "${TEMP_ADMIN_USER}" &>/dev/null; then
    log_warning "Temporary admin '${TEMP_ADMIN_USER}' already exists"
    if ! confirm "Continue anyway? This may be from a previous migration attempt"; then
        log_error "Migration cancelled - please remove ${TEMP_ADMIN_USER} first"
        exit 1
    fi
fi

# Check 3: Verify we're not in an SSH session (unsafe for username change)
if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ]; then
    log_error "═══════════════════════════════════════════════════════════════"
    log_error "⚠️  YOU ARE IN AN SSH SESSION!"
    log_error "═══════════════════════════════════════════════════════════════"
    log_error "Username changes CANNOT be done via SSH (session will disconnect)"
    log_error "Please run this script from:"
    log_error "  - Physical console access"
    log_error "  - Screen sharing session"
    log_error "  - Local Terminal app"
    log_error "═══════════════════════════════════════════════════════════════"
    exit 1
fi
log_success "Not in SSH session (safe to proceed)"

# Check 4: Verify admin privileges
if ! groups | grep -q admin; then
    log_error "Current user must be an administrator"
    log_error "Add ${CURRENT_USER} to admin group first"
    exit 1
fi
log_success "User has admin privileges"

log_info ""
log_warning "═══════════════════════════════════════════════════════════════"
log_warning "⚠️  CRITICAL WARNINGS"
log_warning "═══════════════════════════════════════════════════════════════"
log_warning "This script will:"
log_warning "  1. Create a temporary admin account"
log_warning "  2. Change hostname (requires sudo password)"
log_warning "  3. Instruct you to log out and log in as temp admin"
log_warning "  4. Provide a script for temp admin to rename your user"
log_warning ""
log_warning "⚠️  ALL OPEN APPLICATIONS WILL BE CLOSED"
log_warning "⚠️  YOU WILL BE LOGGED OUT DURING THE PROCESS"
log_warning "⚠️  KEEP THIS TERMINAL WINDOW INSTRUCTIONS VISIBLE"
log_warning "═══════════════════════════════════════════════════════════════"
log_info ""

if ! confirm "Do you understand and want to proceed?"; then
    log_info "Migration cancelled by user"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# PHASE 1: PRE-MIGRATION BACKUP (Run original script)
# ═══════════════════════════════════════════════════════════════

log_info "═══════════════════════════════════════════════════════════════"
log_info "PHASE 1: Running Pre-Migration Backup"
log_info "═══════════════════════════════════════════════════════════════"

if [ "${SKIP_BACKUP}" = "true" ]; then
    log_warning "Skipping backup (--skip-backup flag set)"
    log_warning "Make sure you have a backup from a previous run!"
else
    "${SCRIPT_DIR}/pre-migration-v2.sh" --name="${NEW_USERNAME}" --host="${NEW_HOSTNAME}"

    if [ $? -ne 0 ]; then
        log_error "Pre-migration backup failed!"
        exit 1
    fi
fi

# ═══════════════════════════════════════════════════════════════
# PHASE 2: CHANGE HOSTNAME (Automated)
# ═══════════════════════════════════════════════════════════════

log_info "═══════════════════════════════════════════════════════════════"
log_info "PHASE 2: Changing Hostname"
log_info "═══════════════════════════════════════════════════════════════"

log_info "Current hostname: ${OLD_HOSTNAME}"
log_info "New hostname: ${NEW_HOSTNAME}"

if confirm "Change hostname now?"; then
    log_info "Changing hostname (requires sudo password)..."

    sudo scutil --set ComputerName "${NEW_HOSTNAME}"
    sudo scutil --set LocalHostName "${NEW_HOSTNAME}"
    sudo scutil --set HostName "${NEW_HOSTNAME}"

    log_info "Flushing DNS cache..."
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null || true

    # Verify hostname change
    NEW_HOSTNAME_CHECK=$(scutil --get ComputerName)
    if [ "${NEW_HOSTNAME_CHECK}" = "${NEW_HOSTNAME}" ]; then
        log_success "Hostname changed successfully to: ${NEW_HOSTNAME}"
    else
        log_error "Hostname change failed!"
        exit 1
    fi
else
    log_warning "Hostname change skipped - you'll need to do this manually"
fi

# ═══════════════════════════════════════════════════════════════
# PHASE 3: CREATE TEMPORARY ADMIN (Automated with confirmation)
# ═══════════════════════════════════════════════════════════════

log_info "═══════════════════════════════════════════════════════════════"
log_info "PHASE 3: Creating Temporary Admin Account"
log_info "═══════════════════════════════════════════════════════════════"

if ! id "${TEMP_ADMIN_USER}" &>/dev/null; then
    log_info "Will create temporary admin account: ${TEMP_ADMIN_USER}"

    # Fixed password for temp admin
    TEMP_ADMIN_PASS="123456"

    log_info "Temporary password: ${TEMP_ADMIN_PASS}"
    log_warning "⚠️  WRITE THIS DOWN: ${TEMP_ADMIN_PASS}"
    log_warning "You'll need it to log in as tempadmin"

    if confirm "Create temporary admin account?"; then
        log_info "Creating admin account (requires sudo)..."

        # Create user
        sudo dscl . -create "/Users/${TEMP_ADMIN_USER}"
        sudo dscl . -create "/Users/${TEMP_ADMIN_USER}" UserShell /bin/zsh
        sudo dscl . -create "/Users/${TEMP_ADMIN_USER}" RealName "${TEMP_ADMIN_FULLNAME}"
        sudo dscl . -create "/Users/${TEMP_ADMIN_USER}" UniqueID 401
        sudo dscl . -create "/Users/${TEMP_ADMIN_USER}" PrimaryGroupID 80
        sudo dscl . -create "/Users/${TEMP_ADMIN_USER}" NFSHomeDirectory "/Users/${TEMP_ADMIN_USER}"

        # Set password
        sudo dscl . -passwd "/Users/${TEMP_ADMIN_USER}" "${TEMP_ADMIN_PASS}"

        # Add to admin group
        sudo dscl . -append /Groups/admin GroupMembership "${TEMP_ADMIN_USER}"

        # Create home directory
        sudo createhomedir -c -u "${TEMP_ADMIN_USER}" 2>/dev/null || true

        log_success "Temporary admin account created successfully"

        # Save credentials to file for next phase
        cat > "${HOME}/migration-credentials.txt" <<EOF
Temporary Admin Credentials
============================
Username: ${TEMP_ADMIN_USER}
Password: ${TEMP_ADMIN_PASS}
Created: $(date)

IMPORTANT: Delete this file after migration is complete.
EOF
        chmod 600 "${HOME}/migration-credentials.txt"
        log_success "Credentials saved to: ${HOME}/migration-credentials.txt"
    else
        log_error "Cannot proceed without temporary admin account"
        exit 1
    fi
else
    log_warning "Temporary admin '${TEMP_ADMIN_USER}' already exists"
    TEMP_ADMIN_PASS="123456"

    log_info "Resetting password to: ${TEMP_ADMIN_PASS}"
    sudo dscl . -passwd "/Users/${TEMP_ADMIN_USER}" "${TEMP_ADMIN_PASS}"
    log_success "Password reset to ${TEMP_ADMIN_PASS}"

    # Update credentials file
    cat > "${HOME}/migration-credentials.txt" <<EOF
Temporary Admin Credentials
============================
Username: ${TEMP_ADMIN_USER}
Password: ${TEMP_ADMIN_PASS}
Updated: $(date)

IMPORTANT: Delete this file after migration is complete.
EOF
    chmod 600 "${HOME}/migration-credentials.txt"
    log_success "Credentials saved to: ${HOME}/migration-credentials.txt"
fi

# ═══════════════════════════════════════════════════════════════
# PHASE 4: CREATE USER RENAME SCRIPT (for temp admin to run)
# ═══════════════════════════════════════════════════════════════

log_info "═══════════════════════════════════════════════════════════════"
log_info "PHASE 4: Creating User Rename Script"
log_info "═══════════════════════════════════════════════════════════════"

RENAME_SCRIPT="/Users/${TEMP_ADMIN_USER}/rename-user.sh"

sudo tee "${RENAME_SCRIPT}" > /dev/null <<RENAME_SCRIPT_CONTENT
#!/bin/bash
# User Rename Script - Run as ${TEMP_ADMIN_USER}
# This script MUST be run while logged in as temp admin

set -euo pipefail

OLD_USER="${OLD_USERNAME}"
NEW_USER="${NEW_USERNAME}"

echo "═══════════════════════════════════════════════════════════════"
echo "  USER RENAME SCRIPT"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Old username: \${OLD_USER}"
echo "New username: \${NEW_USER}"
echo ""

# Safety check: Must be running as temp admin
if [ "\$(whoami)" != "${TEMP_ADMIN_USER}" ]; then
    echo "ERROR: Must run as ${TEMP_ADMIN_USER}"
    echo "Current user: \$(whoami)"
    exit 1
fi

# Safety check: Old user must not be logged in
if who | grep -q "\${OLD_USER}"; then
    echo "ERROR: User '\${OLD_USER}' is still logged in!"
    echo "Please log out all sessions for \${OLD_USER} first"
    exit 1
fi

# Safety check: New user must not already exist
if id "\${NEW_USER}" &>/dev/null; then
    echo "ERROR: User '\${NEW_USER}' already exists!"
    exit 1
fi

# Safety check: Old home must exist
if [ ! -d "/Users/\${OLD_USER}" ]; then
    echo "ERROR: Home directory /Users/\${OLD_USER} not found!"
    exit 1
fi

# Safety check: New home must NOT exist (unless it's a partial copy from a failed attempt)
if [ -d "/Users/\${NEW_USER}" ]; then
    echo "⚠️  Directory /Users/\${NEW_USER} already exists!"
    echo "  This is likely a partial copy from a previous failed migration attempt."
    echo ""
    echo "  /Users/\${OLD_USER} size: \$(du -sh /Users/\${OLD_USER} 2>/dev/null | cut -f1)"
    echo "  /Users/\${NEW_USER} size: \$(du -sh /Users/\${NEW_USER} 2>/dev/null | cut -f1)"
    echo ""
    read -p "  Delete /Users/\${NEW_USER} to free space and retry? (type 'yes'): " cleanup_confirm
    if [ "\${cleanup_confirm}" = "yes" ]; then
        echo "  Removing partial copy..."
        sudo rm -rf /Users/\${NEW_USER}
        echo "  ✅ Partial copy removed. Free space recovered."
    else
        echo "  Cannot proceed with existing directory. Exiting."
        exit 1
    fi
fi

echo "All safety checks passed"
echo ""
read -p "Proceed with user rename? (type 'yes' to continue): " confirm
if [ "\${confirm}" != "yes" ]; then
    echo "Rename cancelled"
    exit 1
fi

# ── Step 1/5: Update home directory pointer in Directory Services ──
echo ""
echo "Step 1/5: Updating home directory path in user record..."
if ! sudo dscl . -change /Users/\${OLD_USER} NFSHomeDirectory /Users/\${OLD_USER} /Users/\${NEW_USER}; then
    echo "❌ ERROR: Failed to update NFSHomeDirectory"
    exit 1
fi
echo "✅ Home directory path updated in database"

# ── Step 2/5: Rename the home directory ──
echo ""
echo "Step 2/5: Renaming home directory..."
echo "  Stripping ACL on /Users/\${OLD_USER} (macOS puts 'group:everyone deny delete' on home dirs)..."
sudo chmod -N /Users/\${OLD_USER}

if ! sudo mv /Users/\${OLD_USER} /Users/\${NEW_USER}; then
    echo "❌ ERROR: Failed to move home directory"
    echo "  Rolling back NFSHomeDirectory change..."
    sudo dscl . -change /Users/\${OLD_USER} NFSHomeDirectory /Users/\${NEW_USER} /Users/\${OLD_USER}
    echo "  Restoring ACL..."
    sudo chmod +a "group:everyone deny delete" /Users/\${OLD_USER}
    echo "  Rollback complete. Please investigate the error."
    exit 1
fi
echo "  Restoring ACL on /Users/\${NEW_USER}..."
sudo chmod +a "group:everyone deny delete" /Users/\${NEW_USER}
echo "✅ Home directory renamed"

# ── Step 3/5: Rename the user account (RecordName) ──
echo ""
echo "Step 3/5: Renaming user account..."
if ! sudo dscl . -change /Users/\${OLD_USER} RecordName \${OLD_USER} \${NEW_USER}; then
    echo "❌ ERROR: Failed to rename user account"
    echo "  Rolling back home directory move..."
    sudo chmod -N /Users/\${NEW_USER}
    sudo mv /Users/\${NEW_USER} /Users/\${OLD_USER}
    sudo chmod +a "group:everyone deny delete" /Users/\${OLD_USER}
    echo "  Rolling back NFSHomeDirectory..."
    sudo dscl . -change /Users/\${OLD_USER} NFSHomeDirectory /Users/\${NEW_USER} /Users/\${OLD_USER}
    echo "  Rollback complete. Please investigate the error."
    exit 1
fi
echo "✅ User account renamed"

# ── Step 4/5: Create compatibility symlink ──
echo ""
echo "Step 4/5: Creating compatibility symlink..."
sudo ln -s /Users/\${NEW_USER} /Users/\${OLD_USER}
echo "✅ Symlink created: /Users/\${OLD_USER} → /Users/\${NEW_USER}"
echo "  (Apps with hardcoded old paths will still work)"

# ── Step 5/5: Fix ownership ──
echo ""
echo "Step 5/5: Fixing ownership..."
sudo chown -R \${NEW_USER}:staff /Users/\${NEW_USER}
echo "✅ Ownership fixed"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ USER RENAME COMPLETE!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "1. Log out of ${TEMP_ADMIN_USER}"
echo "2. Log in as \${NEW_USER} (use your OLD password)"
echo "3. Run: cd ~/machine-rename && ./post-migration-fix.sh --name=\${NEW_USER} --host=${NEW_HOSTNAME}"
echo ""
RENAME_SCRIPT_CONTENT

sudo chmod +x "${RENAME_SCRIPT}"
sudo chown "${TEMP_ADMIN_USER}:staff" "${RENAME_SCRIPT}"

log_success "User rename script created: ${RENAME_SCRIPT}"

# ═══════════════════════════════════════════════════════════════
# PHASE 5: INSTRUCTIONS FOR MANUAL STEPS
# ═══════════════════════════════════════════════════════════════

log_info "═══════════════════════════════════════════════════════════════"
log_info "PHASE 5: Manual Steps Required"
log_info "═══════════════════════════════════════════════════════════════"

# Create instruction file
INSTRUCTION_FILE="${HOME}/MIGRATION-INSTRUCTIONS.txt"
cat > "${INSTRUCTION_FILE}" <<INSTRUCTIONS
═══════════════════════════════════════════════════════════════
  MIGRATION INSTRUCTIONS - FOLLOW CAREFULLY
═══════════════════════════════════════════════════════════════

Current Status:
✅ Backup completed
✅ Hostname changed to: ${NEW_HOSTNAME}
✅ Temporary admin created: ${TEMP_ADMIN_USER}
✅ User rename script ready

Next Steps:
═══════════════════════════════════════════════════════════════

STEP 1: LOG OUT
───────────────────────────────────────────────────────────────
  - Click Apple menu → Log Out ${OLD_USERNAME}
  - Or press: ⌘⇧Q

STEP 2: LOG IN AS TEMP ADMIN
───────────────────────────────────────────────────────────────
  Username: ${TEMP_ADMIN_USER}
  Password: (see ~/migration-credentials.txt)

STEP 3: RUN RENAME SCRIPT
───────────────────────────────────────────────────────────────
  Open Terminal and run:

  cd ~
  ./rename-user.sh

  This will rename ${OLD_USERNAME} → ${NEW_USERNAME}
  and move home directory.

STEP 4: LOG OUT OF TEMP ADMIN
───────────────────────────────────────────────────────────────
  - Click Apple menu → Log Out ${TEMP_ADMIN_USER}

STEP 5: LOG IN AS NEW USER
───────────────────────────────────────────────────────────────
  Username: ${NEW_USERNAME}
  Password: (your SAME OLD password)

STEP 6: RUN POST-MIGRATION FIXES
───────────────────────────────────────────────────────────────
  Open Terminal and run:

  cd ~/machine-rename
  ./post-migration-fix.sh --name=${NEW_USERNAME} --host=${NEW_HOSTNAME}

STEP 7: VERIFY MIGRATION
───────────────────────────────────────────────────────────────
  ./verify-migration.sh --name=${NEW_USERNAME} --host=${NEW_HOSTNAME}

STEP 8: CLEANUP (after verification passes)
───────────────────────────────────────────────────────────────
  Delete temp admin:
  - System Preferences → Users & Groups
  - Delete: ${TEMP_ADMIN_USER}

═══════════════════════════════════════════════════════════════

Backup Location: ${BACKUP_ROOT}
Log File: ${LOG_FILE}

If anything goes wrong, restore from backup:
  ${BACKUP_ROOT}/restore-backup.sh

═══════════════════════════════════════════════════════════════
INSTRUCTIONS

log_success "Instructions saved to: ${INSTRUCTION_FILE}"

echo ""
log_warning "═══════════════════════════════════════════════════════════════"
log_warning "  AUTOMATED PORTION COMPLETE"
log_warning "═══════════════════════════════════════════════════════════════"
echo ""
log_info "What was automated:"
log_success "  ✅ Full backup of all data"
log_success "  ✅ Hostname changed to: ${NEW_HOSTNAME}"
log_success "  ✅ Temporary admin account created"
log_success "  ✅ User rename script prepared"
log_success "  ✅ Instructions generated"
echo ""
log_warning "What you need to do manually (takes ~15 min):"
log_warning "  1. Log out (⌘⇧Q)"
log_warning "  2. Log in as: ${TEMP_ADMIN_USER}"
log_warning "  3. Run: ~/rename-user.sh"
log_warning "  4. Log out and log in as: ${NEW_USERNAME}"
log_warning "  5. Run: ~/machine-rename/post-migration-fix.sh"
log_warning "  6. Run: ~/machine-rename/verify-migration.sh"
echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_info "READY TO PROCEED"
log_info "═══════════════════════════════════════════════════════════════"
echo ""
log_info "Credentials file: ${HOME}/migration-credentials.txt"
log_info "Instructions: ${HOME}/MIGRATION-INSTRUCTIONS.txt"
log_info "Rename script: ${RENAME_SCRIPT}"
echo ""

# Open instructions in default text editor
if confirm "Open instructions file now?"; then
    open "${INSTRUCTION_FILE}"
fi

echo ""
log_warning "⚠️  When ready, log out and follow the instructions ⚠️"
echo ""

# Offer to log out now
if confirm "Log out NOW to continue migration?"; then
    log_info "Logging out in 5 seconds..."
    sleep 1
    log_info "4..."
    sleep 1
    log_info "3..."
    sleep 1
    log_info "2..."
    sleep 1
    log_info "1..."
    sleep 1

    # macOS logout command
    osascript -e 'tell application "System Events" to log out'
else
    log_info "Migration paused - log out manually when ready"
    log_info "After logging out, follow: ${INSTRUCTION_FILE}"
fi
