#!/bin/bash
# Migration Configuration v2.1
# Now supports command-line arguments!
# Usage: source this file, then call with --name=X --host=Y

# Version
VERSION="2.1.0"
DATE="2026-02-12"

# ═══════════════════════════════════════════════════════════════
# COMMAND-LINE ARGUMENT PARSING
# ═══════════════════════════════════════════════════════════════

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name=*)
                NEW_USERNAME="${1#*=}"
                shift
                ;;
            --host=*)
                NEW_HOSTNAME="${1#*=}"
                shift
                ;;
            --machine-id=*)
                MACHINE_ID="${1#*=}"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

show_usage() {
    cat << 'EOF'
Usage: ./script.sh --name=USERNAME --host=HOSTNAME [OPTIONS]

Required Arguments:
  --name=USERNAME       New username (e.g., minionstuart, minionkevin)
  --host=HOSTNAME       New hostname (e.g., minion-stuart, minion-kevin)

Optional Arguments:
  --machine-id=ID       Machine identifier (default: derived from hostname)
  --dry-run             Test without making changes
  --skip-backup         Skip Phase 1 backup (use when retrying a failed migration)
  -h, --help            Show this help message

Examples:
  ./pre-migration-v2.sh --name=minionstuart --host=minion-stuart
  ./pre-migration-v2.sh --name=minionkevin --host=minion-kevin --dry-run
  ./post-migration-fix.sh --name=minionbob --host=minion-bob
  ./verify-migration.sh --name=minionstuart --host=minion-stuart

Supported Machines (examples):
  Stuart: --name=minionstuart --host=minion-stuart
  Kevin:  --name=minionkevin --host=minion-kevin
  Bob:    --name=minionbob --host=minion-bob

  Or use ANY custom names you want!
EOF
}

# ═══════════════════════════════════════════════════════════════
# AUTO-DETECTION
# ═══════════════════════════════════════════════════════════════

# Current machine identity (auto-detected)
CURRENT_USERNAME=$(whoami)
CURRENT_HOSTNAME=$(scutil --get ComputerName 2>/dev/null || hostname -s)

# Old identity (will be current if migrating, or can be overridden)
OLD_USERNAME="${OLD_USERNAME:-${CURRENT_USERNAME}}"
OLD_HOSTNAME="${OLD_HOSTNAME:-${CURRENT_HOSTNAME}}"

# ═══════════════════════════════════════════════════════════════
# DEFAULT CONFIGURATION (if no args provided)
# ═══════════════════════════════════════════════════════════════

# New identity - will be overridden by command-line args
NEW_USERNAME="${NEW_USERNAME:-}"
NEW_HOSTNAME="${NEW_HOSTNAME:-}"
MACHINE_ID="${MACHINE_ID:-}"

# ═══════════════════════════════════════════════════════════════
# BACKUP & LOGGING CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# Backup location (will be set after MACHINE_ID is determined)
BACKUP_ROOT=""

# Log file location (will be set after MACHINE_ID is determined)
LOG_FILE=""

# Keep old backups
KEEP_OLD_BACKUPS=true

# ═══════════════════════════════════════════════════════════════
# VERIFICATION CONFIGURATION
# ═══════════════════════════════════════════════════════════════

VERIFY_CLAUDE=true
VERIFY_GIT=true
VERIFY_SSH=true
VERIFY_GCLOUD=true
VERIFY_DOCKER=true
VERIFY_NETWORK=true

# ═══════════════════════════════════════════════════════════════
# SAFETY CHECKS
# ═══════════════════════════════════════════════════════════════

REQUIRE_CONFIRMATION=true
DRY_RUN=false
SKIP_BACKUP=false
IDEMPOTENT_MODE=true

# ═══════════════════════════════════════════════════════════════
# ADVANCED SETTINGS
# ═══════════════════════════════════════════════════════════════

RESTART_SERVICES=(
    "com.docker.helper"
)

PATHS_TO_AUDIT=(
    "${HOME}/.zshrc"
    "${HOME}/.zprofile"
    "${HOME}/.bashrc"
    "${HOME}/.bash_profile"
    "${HOME}/.config"
    "${HOME}/.claude"
    "${HOME}/.ssh/config"
)

APPS_TO_CHECK=(
    "Docker Desktop"
    "Claude Code"
    "Cursor"
    "VS Code"
)

# ═══════════════════════════════════════════════════════════════
# INITIALIZATION FUNCTION
# ═══════════════════════════════════════════════════════════════

init_config() {
    # Parse command-line arguments if provided
    if [ $# -gt 0 ]; then
        parse_args "$@"
    fi

    # Derive MACHINE_ID from hostname if not provided
    if [ -z "${MACHINE_ID}" ] && [ -n "${NEW_HOSTNAME}" ]; then
        # Use full hostname as machine ID (e.g., minion-kevin)
        MACHINE_ID="${NEW_HOSTNAME}"
    fi

    # Set backup and log locations now that MACHINE_ID is known
    if [ -n "${MACHINE_ID}" ]; then
        BACKUP_ROOT="/tmp/migration-backup-${MACHINE_ID}"
        LOG_FILE="${HOME}/migration-log-${MACHINE_ID}.txt"
    else
        BACKUP_ROOT="/tmp/migration-backup"
        LOG_FILE="${HOME}/migration-log.txt"
    fi

    # Validate configuration
    validate_config
}

# ═══════════════════════════════════════════════════════════════
# VALIDATION
# ═══════════════════════════════════════════════════════════════

validate_config() {
    local errors=0

    # Check required variables
    if [ -z "${NEW_USERNAME}" ]; then
        echo "ERROR: NEW_USERNAME not set"
        echo "Use: --name=USERNAME"
        errors=$((errors + 1))
    fi

    if [ -z "${NEW_HOSTNAME}" ]; then
        echo "ERROR: NEW_HOSTNAME not set"
        echo "Use: --host=HOSTNAME"
        errors=$((errors + 1))
    fi

    if [ ${errors} -gt 0 ]; then
        echo ""
        show_usage
        return ${errors}
    fi

    # Check username format (lowercase alphanumeric only)
    if ! echo "${NEW_USERNAME}" | grep -qE '^[a-z][a-z0-9]*$'; then
        echo "ERROR: NEW_USERNAME must be lowercase alphanumeric, starting with letter"
        echo "Got: ${NEW_USERNAME}"
        errors=$((errors + 1))
    fi

    # Check hostname format (lowercase alphanumeric with hyphens)
    if ! echo "${NEW_HOSTNAME}" | grep -qE '^[a-z][a-z0-9-]*$'; then
        echo "ERROR: NEW_HOSTNAME must be lowercase alphanumeric with hyphens"
        echo "Got: ${NEW_HOSTNAME}"
        errors=$((errors + 1))
    fi

    # Check if old and new are different
    if [ "${OLD_USERNAME}" = "${NEW_USERNAME}" ]; then
        echo "WARNING: OLD_USERNAME and NEW_USERNAME are the same"
        echo "  Current: ${OLD_USERNAME}"
        echo "  Target: ${NEW_USERNAME}"
        echo "  Migration may not be necessary"
    fi

    if [ "${OLD_HOSTNAME}" = "${NEW_HOSTNAME}" ]; then
        echo "WARNING: OLD_HOSTNAME and NEW_HOSTNAME are the same"
        echo "  Current: ${OLD_HOSTNAME}"
        echo "  Target: ${NEW_HOSTNAME}"
        echo "  Migration may not be necessary"
    fi

    return $errors
}

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "${LOG_FILE}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "${LOG_FILE}"
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${CYAN}🔍 $1${NC}" | tee -a "${LOG_FILE}"
    fi
}

# Confirmation helper
confirm() {
    local prompt="$1"

    if [ "${REQUIRE_CONFIRMATION}" != "true" ]; then
        return 0
    fi

    if [ "${DRY_RUN}" = "true" ]; then
        log_info "[DRY RUN] Would ask: ${prompt}"
        return 0
    fi

    read -p "${prompt} [y/N]: " response
    case "${response}" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Dry-run wrapper
dry_run() {
    if [ "${DRY_RUN}" = "true" ]; then
        log_info "[DRY RUN] Would execute: $*"
        return 0
    else
        "$@"
    fi
}

# Network check helper
check_network_hostname() {
    local hostname="$1"
    log_info "Checking if hostname '${hostname}' is unique on network..."

    if ping -c 1 -t 1 "${hostname}.local" &>/dev/null; then
        log_warning "Hostname '${hostname}.local' already responds on network!"
        return 1
    else
        log_success "Hostname '${hostname}' is unique"
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════
# CONFIGURATION SUMMARY
# ═══════════════════════════════════════════════════════════════

print_config_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  MIGRATION CONFIGURATION"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Machine ID: ${MACHINE_ID:-auto-detected}"
    echo ""
    echo "  CURRENT Identity:"
    echo "    Username: ${OLD_USERNAME}"
    echo "    Hostname: ${OLD_HOSTNAME}"
    echo "    Home: /Users/${OLD_USERNAME}"
    echo ""
    echo "  TARGET Identity:"
    echo "    Username: ${NEW_USERNAME}"
    echo "    Hostname: ${NEW_HOSTNAME}"
    echo "    Home: /Users/${NEW_USERNAME}"
    echo ""
    echo "  Backup Location: ${BACKUP_ROOT}"
    echo "  Log File: ${LOG_FILE}"
    echo "  Dry Run: ${DRY_RUN}"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# EXPORT VARIABLES
# ═══════════════════════════════════════════════════════════════

export OLD_USERNAME NEW_USERNAME OLD_HOSTNAME NEW_HOSTNAME MACHINE_ID
export BACKUP_ROOT LOG_FILE KEEP_OLD_BACKUPS
export VERIFY_CLAUDE VERIFY_GIT VERIFY_SSH VERIFY_GCLOUD VERIFY_DOCKER VERIFY_NETWORK
export REQUIRE_CONFIRMATION DRY_RUN SKIP_BACKUP IDEMPOTENT_MODE
export RED GREEN YELLOW BLUE MAGENTA CYAN NC

# ═══════════════════════════════════════════════════════════════
# DIRECT EXECUTION (for testing)
# ═══════════════════════════════════════════════════════════════

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Running directly (for testing)
    init_config "$@"
    print_config_summary
fi
