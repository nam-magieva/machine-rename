#!/bin/bash
# Pre-Migration Script v2.0
# Includes: Pre-flight checks, idempotency, network validation
# Date: 2026-02-12

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/migration-config-v2.sh" ]; then
    source "${SCRIPT_DIR}/migration-config-v2.sh"
    # Initialize with command-line arguments
    init_config "$@"
else
    echo "ERROR: migration-config-v2.sh not found!"
    exit 1
fi

log_info "═══════════════════════════════════════════════════════════════"
log_info "  PRE-MIGRATION SCRIPT v2.0"
log_info "═══════════════════════════════════════════════════════════════"

print_config_summary

# ═══════════════════════════════════════════════════════════════
# PHASE 1: PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════

log_info "═══════════════════════════════════════════════════════════════"
log_info "PHASE 1: Pre-Flight Validation"
log_info "═══════════════════════════════════════════════════════════════"

PREFLIGHT_ERRORS=0

# Check 1: Running as correct user
log_info "Checking current user..."
CURRENT_USER=$(whoami)
if [ "${CURRENT_USER}" != "${OLD_USERNAME}" ]; then
    log_error "Must run as user: ${OLD_USERNAME}"
    log_error "Current user: ${CURRENT_USER}"
    PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
else
    log_success "Running as correct user: ${CURRENT_USER}"
fi

# Check 2: Not running as root
if [ "${EUID}" -eq 0 ]; then
    log_error "Do not run this script as root or with sudo"
    PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
fi

# Check 3: Check if new username already exists
log_info "Checking if target username already exists..."
if id "${NEW_USERNAME}" &>/dev/null; then
    log_error "User '${NEW_USERNAME}' already exists!"
    log_error "Cannot migrate to existing username"
    PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
else
    log_success "Target username '${NEW_USERNAME}' is available"
fi

# Check 4: Check if new home directory already exists
log_info "Checking if target home directory exists..."
if [ -d "/Users/${NEW_USERNAME}" ]; then
    log_error "Directory /Users/${NEW_USERNAME} already exists!"
    log_error "Cannot migrate to existing directory"
    PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
else
    log_success "Target home directory is available"
fi

# Check 5: Check disk space
log_info "Checking disk space..."
# Simplified check: just verify we have at least 20GB free
# (estimating home dir is usually < 100GB, so 20GB buffer should be safe)
AVAILABLE=$(df -m /Users | tail -1 | awk '{print $4}')
MINIMUM_REQUIRED=20000  # 20GB minimum

log_info "Available space: ${AVAILABLE} MB"
log_info "Minimum required: ${MINIMUM_REQUIRED} MB (20GB safety buffer)"

if [ "${AVAILABLE}" -lt "${MINIMUM_REQUIRED}" ]; then
    log_error "Insufficient disk space!"
    log_error "Need at least ${MINIMUM_REQUIRED} MB, have ${AVAILABLE} MB"
    PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
else
    log_success "Sufficient disk space available"
fi

# Check 6: Check network hostname availability
if [ "${VERIFY_NETWORK}" = "true" ]; then
    log_info "Checking network hostname availability..."
    if check_network_hostname "${NEW_HOSTNAME}"; then
        log_success "Hostname '${NEW_HOSTNAME}' is available on network"
    else
        log_warning "Hostname '${NEW_HOSTNAME}' may conflict on network"
        log_warning "Proceed with caution - may cause mDNS issues"
        # Not a fatal error, but worth noting
    fi
fi

# Check 7: Check for running applications
log_info "Checking for running applications..."
RUNNING_APPS=()
for app in "${APPS_TO_CHECK[@]}"; do
    if pgrep -f "${app}" >/dev/null; then
        RUNNING_APPS+=("${app}")
        log_warning "Application running: ${app}"
    fi
done

if [ ${#RUNNING_APPS[@]} -gt 0 ]; then
    log_warning "Found ${#RUNNING_APPS[@]} running applications"
    log_warning "Recommend closing before migration:"
    for app in "${RUNNING_APPS[@]}"; do
        log_warning "  - ${app}"
    done
fi

# Check 8: Check for uncommitted git changes
log_info "Checking for uncommitted changes in repositories..."
DIRTY_REPOS=0
if [ -d "${HOME}/.claude-config/.git" ]; then
    cd "${HOME}/.claude-config"
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warning "Uncommitted changes in .claude-config"
        DIRTY_REPOS=$((DIRTY_REPOS + 1))
    fi
fi

if [ ${DIRTY_REPOS} -gt 0 ]; then
    log_warning "Found ${DIRTY_REPOS} repositories with uncommitted changes"
    log_warning "Recommend committing before migration"
fi

# Check 9: Check backup destination
log_info "Checking backup destination..."
BACKUP_DIR=$(dirname "${BACKUP_ROOT}")
if [ ! -d "${BACKUP_DIR}" ]; then
    log_warning "Backup directory parent doesn't exist: ${BACKUP_DIR}"
    log_info "Will create: ${BACKUP_ROOT}"
fi

if [ -d "${BACKUP_ROOT}" ]; then
    if [ "${KEEP_OLD_BACKUPS}" = "true" ]; then
        OLD_BACKUP="${BACKUP_ROOT}.$(date +%Y%m%d-%H%M%S)"
        log_info "Previous backup exists - will rename to: ${OLD_BACKUP}"
    else
        log_warning "Previous backup exists and will be OVERWRITTEN"
    fi
fi

# Check 10: Verify required tools
log_info "Checking required tools..."
REQUIRED_TOOLS=(rsync git ssh scutil)
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "${tool}" &>/dev/null; then
        log_error "Required tool not found: ${tool}"
        PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
    fi
done

# Pre-flight summary
echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_info "Pre-Flight Check Summary:"
log_info "  Errors: ${PREFLIGHT_ERRORS}"
log_info "  Warnings: ${#RUNNING_APPS[@]} running apps, ${DIRTY_REPOS} dirty repos"
log_info "═══════════════════════════════════════════════════════════════"
echo ""

if [ ${PREFLIGHT_ERRORS} -gt 0 ]; then
    log_error "Pre-flight checks FAILED with ${PREFLIGHT_ERRORS} errors"
    log_error "Please fix errors before proceeding"
    exit 1
fi

log_success "Pre-flight checks PASSED"
echo ""

# Confirmation
if ! confirm "Proceed with backup? This will take ~10 minutes"; then
    log_info "Backup cancelled by user"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# PHASE 2: BACKUP
# ═══════════════════════════════════════════════════════════════

log_info "═══════════════════════════════════════════════════════════════"
log_info "PHASE 2: Backup Process"
log_info "═══════════════════════════════════════════════════════════════"

# Handle existing backup
if [ -d "${BACKUP_ROOT}" ]; then
    if [ "${KEEP_OLD_BACKUPS}" = "true" ]; then
        OLD_BACKUP="${BACKUP_ROOT}.$(date +%Y%m%d-%H%M%S)"
        log_info "Renaming old backup to: ${OLD_BACKUP}"
        dry_run mv "${BACKUP_ROOT}" "${OLD_BACKUP}"
    else
        log_warning "Removing old backup..."
        dry_run rm -rf "${BACKUP_ROOT}"
    fi
fi

# Create backup directory
log_info "Creating backup directory: ${BACKUP_ROOT}"
dry_run mkdir -p "${BACKUP_ROOT}"

# Save migration state
log_info "Saving migration state..."
cat > "${BACKUP_ROOT}/migration-state.txt" << EOF
Migration Date: $(date)
Machine ID: ${MACHINE_ID}
Old Username: ${OLD_USERNAME}
New Username: ${NEW_USERNAME}
Old Hostname: ${OLD_HOSTNAME}
New Hostname: ${NEW_HOSTNAME}
Old Home: /Users/${OLD_USERNAME}
New Home: /Users/${NEW_USERNAME}
Script Version: 2.0.0
EOF

# 1. Backup SSH configuration
log_info "Backing up SSH config..."
if [ -d "${HOME}/.ssh" ]; then
    dry_run rsync -av "${HOME}/.ssh/" "${BACKUP_ROOT}/ssh/" >> "${LOG_FILE}" 2>&1
    log_success "SSH config backed up"
else
    log_warning "No SSH directory found"
fi

# 2. Backup Git configuration
log_info "Backing up Git config..."
if [ -f "${HOME}/.gitconfig" ]; then
    dry_run cp "${HOME}/.gitconfig" "${BACKUP_ROOT}/gitconfig"
    log_success "Git config backed up"
fi

# 3. Backup shell configurations
log_info "Backing up shell configs..."
for file in .zshrc .zprofile .bashrc .bash_profile .zshenv; do
    if [ -f "${HOME}/${file}" ]; then
        dry_run cp "${HOME}/${file}" "${BACKUP_ROOT}/${file}"
        log_success "Backed up ${file}"
    fi
done

# 4. Backup Claude Code configuration
log_info "Backing up Claude Code config..."
if [ -d "${HOME}/.claude" ]; then
    # Save symlink inventory
    find "${HOME}/.claude" -type l -ls > "${BACKUP_ROOT}/claude-symlinks-before.txt" 2>/dev/null

    dry_run rsync -avL "${HOME}/.claude/" "${BACKUP_ROOT}/claude/" >> "${LOG_FILE}" 2>&1
    log_success "Claude Code config backed up (following symlinks)"
else
    log_warning "No .claude directory found"
fi

# 5. Backup .claude-config repository
log_info "Backing up .claude-config repository..."
if [ -d "${HOME}/.claude-config" ]; then
    cd "${HOME}/.claude-config"
    git status > "${BACKUP_ROOT}/claude-config-git-status.txt" 2>&1 || true
    git log -1 > "${BACKUP_ROOT}/claude-config-git-log.txt" 2>&1 || true

    dry_run rsync -av "${HOME}/.claude-config/" "${BACKUP_ROOT}/claude-config/" >> "${LOG_FILE}" 2>&1
    log_success ".claude-config backed up"
fi

# 6. Backup GCloud configuration
log_info "Backing up GCloud config..."
if [ -d "${HOME}/.config/gcloud" ]; then
    # Only backup config, not the entire virtualenv (too large)
    dry_run rsync -av --exclude='virtenv' "${HOME}/.config/gcloud/" "${BACKUP_ROOT}/gcloud/" >> "${LOG_FILE}" 2>&1
    log_success "GCloud config backed up (excluding virtualenv)"
fi

# 7. Backup Docker configuration
log_info "Backing up Docker config..."
if [ -d "${HOME}/.docker" ]; then
    dry_run rsync -av "${HOME}/.docker/" "${BACKUP_ROOT}/docker/" >> "${LOG_FILE}" 2>&1
    log_success "Docker config backed up"
fi

# 8. Backup Cursor/VS Code settings
log_info "Backing up editor configs..."
for editor_dir in .cursor .vscode; do
    if [ -d "${HOME}/${editor_dir}" ]; then
        dry_run rsync -av "${HOME}/${editor_dir}/" "${BACKUP_ROOT}/${editor_dir}/" >> "${LOG_FILE}" 2>&1
        log_success "Backed up ${editor_dir}"
    fi
done

# 9. Find and catalog Git repositories
log_info "Cataloging Git repositories..."
find "${HOME}" -maxdepth 4 -name ".git" -type d 2>/dev/null | sed 's|/.git||' > "${BACKUP_ROOT}/git-repos-list.txt" || true
REPO_COUNT=$(wc -l < "${BACKUP_ROOT}/git-repos-list.txt" | tr -d ' ')
log_success "Found ${REPO_COUNT} Git repositories"

# 10. Audit hardcoded paths
log_info "Auditing hardcoded paths..."
{
    for path in "${PATHS_TO_AUDIT[@]}"; do
        if [ -e "${path}" ]; then
            grep -r "/Users/${OLD_USERNAME}" "${path}" 2>/dev/null || true
        fi
    done
} > "${BACKUP_ROOT}/hardcoded-paths.txt"
PATH_COUNT=$(wc -l < "${BACKUP_ROOT}/hardcoded-paths.txt" | tr -d ' ')
log_info "Found ${PATH_COUNT} hardcoded path references"

# 11. List all symlinks
log_info "Cataloging all symlinks..."
find "${HOME}/.claude" -type l -ls > "${BACKUP_ROOT}/all-symlinks.txt" 2>/dev/null || true
SYMLINK_COUNT=$(wc -l < "${BACKUP_ROOT}/all-symlinks.txt" | tr -d ' ')
log_success "Found ${SYMLINK_COUNT} symlinks"

# 12. System state snapshot
log_info "Capturing system state..."
cat > "${BACKUP_ROOT}/system-state.txt" << EOF
═══════════════════════════════════════════════════════════════
SYSTEM STATE SNAPSHOT
═══════════════════════════════════════════════════════════════
Date: $(date)
Machine ID: ${MACHINE_ID}

User Information:
  Username: $(whoami)
  UID: $(id -u)
  Groups: $(id -Gn)
  Home: ${HOME}
  Shell: ${SHELL}

Hostname Information:
  ComputerName: $(scutil --get ComputerName 2>/dev/null || echo "not set")
  LocalHostName: $(scutil --get LocalHostName 2>/dev/null || echo "not set")
  HostName: $(scutil --get HostName 2>/dev/null || echo "not set")

System Information:
  $(uname -a)
  $(sw_vers)

Disk Usage:
  $(df -h "${HOME}")

Network:
  Primary IP: $(ipconfig getifaddr en0 2>/dev/null || echo "not connected")
  mDNS Name: $(hostname).local

Running Applications:
  $(ps aux | grep -E "Docker|Claude|Cursor|Code" | grep -v grep || echo "none")

Environment:
  PATH: ${PATH}
  LANG: ${LANG:-not set}
EOF

log_success "System state captured"

# 13. Create restoration script
log_info "Creating restoration script..."
cat > "${BACKUP_ROOT}/restore-backup.sh" << 'RESTORE_SCRIPT'
#!/bin/bash
# Emergency Restoration Script v2.0
# Run this only if migration fails and you need to restore

set -e

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "═══════════════════════════════════════════════════════════════"
echo "  EMERGENCY BACKUP RESTORATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Backup location: ${BACKUP_DIR}"
echo ""

# Read migration state
if [ -f "${BACKUP_DIR}/migration-state.txt" ]; then
    echo "Migration details:"
    cat "${BACKUP_DIR}/migration-state.txt"
    echo ""
fi

# Confirmation
read -p "This will OVERWRITE current configs. Continue? (type 'yes'): " confirm
if [ "${confirm}" != "yes" ]; then
    echo "Restoration cancelled"
    exit 1
fi

echo ""
echo "Starting restoration..."

# Restore SSH
if [ -d "${BACKUP_DIR}/ssh" ]; then
    echo "Restoring SSH config..."
    rsync -av "${BACKUP_DIR}/ssh/" "${HOME}/.ssh/"
    chmod 700 "${HOME}/.ssh"
    chmod 600 "${HOME}/.ssh/"* 2>/dev/null || true
    chmod 644 "${HOME}/.ssh/"*.pub 2>/dev/null || true
fi

# Restore Git config
if [ -f "${BACKUP_DIR}/gitconfig" ]; then
    echo "Restoring Git config..."
    cp "${BACKUP_DIR}/gitconfig" "${HOME}/.gitconfig"
fi

# Restore shell configs
for file in .zshrc .zprofile .bashrc .bash_profile .zshenv; do
    if [ -f "${BACKUP_DIR}/${file}" ]; then
        echo "Restoring ${file}..."
        cp "${BACKUP_DIR}/${file}" "${HOME}/${file}"
    fi
done

# Restore Claude config
if [ -d "${BACKUP_DIR}/claude" ]; then
    echo "Restoring Claude config..."
    rsync -av "${BACKUP_DIR}/claude/" "${HOME}/.claude/"
fi

# Restore .claude-config
if [ -d "${BACKUP_DIR}/claude-config" ]; then
    echo "Restoring .claude-config..."
    rsync -av "${BACKUP_DIR}/claude-config/" "${HOME}/.claude-config/"
fi

# Restore Docker
if [ -d "${BACKUP_DIR}/docker" ]; then
    echo "Restoring Docker config..."
    rsync -av "${BACKUP_DIR}/docker/" "${HOME}/.docker/"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Restoration complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "1. Log out and log back in"
echo "2. Verify applications work correctly"
echo "3. If issues persist, check: ${BACKUP_DIR}/system-state.txt"
RESTORE_SCRIPT

chmod +x "${BACKUP_ROOT}/restore-backup.sh"
log_success "Restoration script created"

# ═══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════

echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_info "BACKUP SUMMARY"
log_info "═══════════════════════════════════════════════════════════════"
log_info "Machine ID: ${MACHINE_ID}"
log_info "Backup Location: ${BACKUP_ROOT}"
BACKUP_SIZE=$(du -sh "${BACKUP_ROOT}" 2>/dev/null | cut -f1)
log_info "Backup Size: ${BACKUP_SIZE}"
log_success "Git Repositories: ${REPO_COUNT}"
log_info "Hardcoded Paths: ${PATH_COUNT}"
log_success "Symlinks Cataloged: ${SYMLINK_COUNT}"
log_info "Log File: ${LOG_FILE}"
log_info "═══════════════════════════════════════════════════════════════"

if [ -d "${BACKUP_ROOT}" ] && [ "$(ls -A ${BACKUP_ROOT} 2>/dev/null)" ]; then
    echo ""
    log_success "═══════════════════════════════════════════════════════════════"
    log_success "✅ BACKUP COMPLETED SUCCESSFULLY"
    log_success "═══════════════════════════════════════════════════════════════"
    echo ""
    log_info "Next steps:"
    log_info "1. Review backup at: ${BACKUP_ROOT}"
    log_info "2. Proceed with hostname change (see MIGRATION-PLAN.md Phase 2)"
    log_info "3. Keep this backup until migration is verified"
    echo ""
    log_info "To restore if needed:"
    log_info "  ${BACKUP_ROOT}/restore-backup.sh"
    echo ""
    exit 0
else
    log_error "❌ BACKUP FAILED - Directory empty or missing"
    exit 1
fi
