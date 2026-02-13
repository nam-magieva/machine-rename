#!/bin/bash
# Post-Migration Fix Script
# Version: 1.0.0
# Date: 2026-02-12
# Run this AFTER username change as NEW user

set -e  # Exit on error

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

log_info "=========================================="
log_info "Post-Migration Fix Script"
log_info "Machine: ${MACHINE_ID}"
log_info "=========================================="

# Check if running as correct user
CURRENT_USER=$(whoami)
if [ "${CURRENT_USER}" != "${NEW_USERNAME}" ]; then
    log_error "Must run as NEW user: ${NEW_USERNAME}"
    log_error "Current user: ${CURRENT_USER}"
    exit 1
fi

log_success "Running as correct user: ${CURRENT_USER}"

# Verify home directory
if [ "${HOME}" != "/Users/${NEW_USERNAME}" ]; then
    log_error "Home directory mismatch!"
    log_error "Expected: /Users/${NEW_USERNAME}"
    log_error "Actual: ${HOME}"
    exit 1
fi

log_success "Home directory correct: ${HOME}"

# 1. Fix Claude Code symlinks
log_info "=========================================="
log_info "Fixing Claude Code Symlinks"
log_info "=========================================="

if [ -d "${HOME}/.claude" ]; then
    cd "${HOME}/.claude"

    # Define symlinks to fix
    declare -A SYMLINKS=(
        ["agents"]="/Users/${NEW_USERNAME}/.claude-config/agents"
        ["CLAUDE.md"]="/Users/${NEW_USERNAME}/.claude-config/shared/CLAUDE.md"
        ["settings.json"]="/Users/${NEW_USERNAME}/.claude-config/shared/settings.json"
        ["skills"]="/Users/${NEW_USERNAME}/.claude-config/skills"
    )

    for link_name in "${!SYMLINKS[@]}"; do
        target="${SYMLINKS[$link_name]}"

        # Remove old symlink if it exists
        if [ -L "${link_name}" ]; then
            log_info "Removing old symlink: ${link_name}"
            rm "${link_name}"
        fi

        # Create new symlink if target exists
        if [ -e "${target}" ]; then
            log_info "Creating symlink: ${link_name} -> ${target}"
            ln -s "${target}" "${link_name}"
            log_success "Created: ${link_name}"
        else
            log_warning "Target not found: ${target}"
        fi
    done

    log_success "Claude Code symlinks fixed"
else
    log_warning "No .claude directory found"
fi

# 2. Fix file ownership
log_info "=========================================="
log_info "Fixing File Ownership"
log_info "=========================================="

log_info "Fixing ownership of home directory..."
sudo chown -R "${NEW_USERNAME}:staff" "${HOME}"
log_success "Ownership fixed"

# 3. Fix GCloud SDK (if exists)
log_info "=========================================="
log_info "Fixing GCloud SDK"
log_info "=========================================="

if [ -d "${HOME}/.config/gcloud" ]; then
    log_info "GCloud config found - checking virtualenv..."

    if [ -d "${HOME}/.config/gcloud/virtenv" ]; then
        log_warning "GCloud virtualenv has hardcoded paths"
        log_info "Reinstalling GCloud SDK..."

        # Check if gcloud is installed via brew
        if command -v brew &> /dev/null && brew list google-cloud-sdk &> /dev/null; then
            log_info "Reinstalling via Homebrew..."
            brew reinstall google-cloud-sdk >> "${LOG_FILE}" 2>&1
            log_success "GCloud SDK reinstalled"
        else
            log_warning "GCloud SDK not installed via Homebrew"
            log_info "Manual reinstall may be required"
            log_info "Run: brew reinstall google-cloud-sdk"
        fi
    fi
else
    log_info "No GCloud SDK found - skipping"
fi

# 4. Update any hardcoded paths in configs
log_info "=========================================="
log_info "Fixing Hardcoded Paths"
log_info "=========================================="

# Check .zshrc for hardcoded paths (excluding API keys and important configs)
if [ -f "${HOME}/.zshrc" ]; then
    log_info "Checking .zshrc for hardcoded paths..."

    # Count occurrences (excluding the line with API key)
    OLD_PATH_COUNT=$(grep -c "/Users/${OLD_USERNAME}" "${HOME}/.zshrc" 2>/dev/null || echo "0")

    if [ "${OLD_PATH_COUNT}" -gt 0 ]; then
        log_warning "Found ${OLD_PATH_COUNT} references to old username in .zshrc"
        log_info "Creating backup before modification..."

        cp "${HOME}/.zshrc" "${HOME}/.zshrc.pre-migration"

        # Replace old paths (be careful with API keys)
        sed -i '' "s|/Users/${OLD_USERNAME}|/Users/${NEW_USERNAME}|g" "${HOME}/.zshrc"

        NEW_COUNT=$(grep -c "/Users/${OLD_USERNAME}" "${HOME}/.zshrc" 2>/dev/null || echo "0")
        if [ "${NEW_COUNT}" -eq 0 ]; then
            log_success ".zshrc paths updated"
        else
            log_warning "Some paths remain - manual review recommended"
        fi
    else
        log_success ".zshrc uses relative paths (no changes needed)"
    fi
fi

# 5. Verify and fix Git config
log_info "=========================================="
log_info "Verifying Git Configuration"
log_info "=========================================="

if [ -f "${HOME}/.gitconfig" ]; then
    log_info "Git config found"

    # Check if git config has old username
    if grep -q "/Users/${OLD_USERNAME}" "${HOME}/.gitconfig"; then
        log_warning "Found old paths in .gitconfig"
        cp "${HOME}/.gitconfig" "${HOME}/.gitconfig.pre-migration"
        sed -i '' "s|/Users/${OLD_USERNAME}|/Users/${NEW_USERNAME}|g" "${HOME}/.gitconfig"
        log_success "Git config paths updated"
    else
        log_success "Git config looks good"
    fi

    # Display user info
    log_info "Git user: $(git config user.name)"
    log_info "Git email: $(git config user.email)"
else
    log_warning "No .gitconfig found"
fi

# 6. Fix SSH config
log_info "=========================================="
log_info "Verifying SSH Configuration"
log_info "=========================================="

if [ -d "${HOME}/.ssh" ]; then
    # Fix SSH permissions (critical)
    chmod 700 "${HOME}/.ssh"
    chmod 600 "${HOME}/.ssh/"* 2>/dev/null || true
    chmod 644 "${HOME}/.ssh/config" 2>/dev/null || true
    chmod 644 "${HOME}/.ssh/"*.pub 2>/dev/null || true

    log_success "SSH permissions fixed"

    # Check SSH config for old paths
    if [ -f "${HOME}/.ssh/config" ]; then
        if grep -q "/Users/${OLD_USERNAME}" "${HOME}/.ssh/config"; then
            log_warning "Found old paths in SSH config"
            cp "${HOME}/.ssh/config" "${HOME}/.ssh/config.pre-migration"
            sed -i '' "s|/Users/${OLD_USERNAME}|/Users/${NEW_USERNAME}|g" "${HOME}/.ssh/config"
            log_success "SSH config paths updated"
        else
            log_success "SSH config looks good"
        fi
    fi
else
    log_warning "No .ssh directory found"
fi

# 7. Reload shell configuration
log_info "=========================================="
log_info "Reloading Shell Configuration"
log_info "=========================================="

if [ -f "${HOME}/.zshrc" ]; then
    log_info "Sourcing .zshrc..."
    source "${HOME}/.zshrc"
    log_success "Shell configuration reloaded"
fi

# 8. List remaining issues
log_info "=========================================="
log_info "Checking for Remaining Issues"
log_info "=========================================="

# Check for broken symlinks
log_info "Checking for broken symlinks in .claude..."
BROKEN_LINKS=$(find "${HOME}/.claude" -type l -exec test ! -e {} \; -print 2>/dev/null || true)

if [ -z "${BROKEN_LINKS}" ]; then
    log_success "No broken symlinks found"
else
    log_warning "Broken symlinks found:"
    echo "${BROKEN_LINKS}" | tee -a "${LOG_FILE}"
fi

# Check for old username references
log_info "Checking for old username references..."
REMAINING_REFS=$(grep -r "/Users/${OLD_USERNAME}" \
    "${HOME}/.zshrc" \
    "${HOME}/.config" \
    2>/dev/null | wc -l || echo "0")

if [ "${REMAINING_REFS}" -eq 0 ]; then
    log_success "No old username references found"
else
    log_warning "Found ${REMAINING_REFS} old username references"
    log_info "Run this to see details:"
    log_info "  grep -r '/Users/${OLD_USERNAME}' ~/.zshrc ~/.config"
fi

# Generate summary
log_info "=========================================="
log_info "POST-MIGRATION FIX SUMMARY"
log_info "=========================================="
log_success "✅ Username: ${NEW_USERNAME}"
log_success "✅ Home directory: ${HOME}"
log_success "✅ Claude Code symlinks: Fixed"
log_success "✅ File ownership: Fixed"
log_success "✅ SSH permissions: Fixed"

if [ "${REMAINING_REFS}" -eq 0 ] && [ -z "${BROKEN_LINKS}" ]; then
    log_success "=========================================="
    log_success "✅ ALL FIXES COMPLETED SUCCESSFULLY"
    log_success "=========================================="
    log_info ""
    log_info "Next steps:"
    log_info "1. Run verification script: ./verify-migration.sh"
    log_info "2. Test Claude Code: claude"
    log_info "3. Test Git: cd ~/.claude-config && git status"
    log_info "4. Test SSH: ssh -T git@github.com"
else
    log_warning "=========================================="
    log_warning "⚠️  FIXES COMPLETED WITH WARNINGS"
    log_warning "=========================================="
    log_info "Manual review recommended for remaining issues"
    log_info "See log file: ${LOG_FILE}"
fi
