#!/bin/bash
# Migration Verification Script
# Version: 1.0.0
# Date: 2026-02-12

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
log_info "Migration Verification Script"
log_info "Machine: ${MACHINE_ID}"
log_info "=========================================="

# Track verification results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

verify_check() {
    local check_name="$1"
    local result="$2"
    local critical="${3:-true}"  # Default: critical

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if [ "${result}" = "pass" ]; then
        log_success "PASS: ${check_name}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    elif [ "${result}" = "warn" ]; then
        log_warning "WARN: ${check_name}"
        WARNINGS=$((WARNINGS + 1))
        return 0
    else
        if [ "${critical}" = "true" ]; then
            log_error "FAIL: ${check_name}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            log_warning "SKIP: ${check_name}"
            WARNINGS=$((WARNINGS + 1))
        fi
        return 1
    fi
}

log_info "Starting verification checks..."
echo ""

# ========================================
# 1. USERNAME VERIFICATION
# ========================================
log_info "=========================================="
log_info "1. Username Verification"
log_info "=========================================="

CURRENT_USER=$(whoami)
if [ "${CURRENT_USER}" = "${NEW_USERNAME}" ]; then
    verify_check "Username is ${NEW_USERNAME}" "pass"
else
    verify_check "Username is ${NEW_USERNAME} (found: ${CURRENT_USER})" "fail"
fi

# ========================================
# 2. HOSTNAME VERIFICATION
# ========================================
log_info "=========================================="
log_info "2. Hostname Verification"
log_info "=========================================="

CURRENT_HOSTNAME=$(scutil --get ComputerName)
if [ "${CURRENT_HOSTNAME}" = "${NEW_HOSTNAME}" ]; then
    verify_check "ComputerName is ${NEW_HOSTNAME}" "pass"
else
    verify_check "ComputerName is ${NEW_HOSTNAME} (found: ${CURRENT_HOSTNAME})" "fail"
fi

CURRENT_LOCAL_HOSTNAME=$(scutil --get LocalHostName)
if [ "${CURRENT_LOCAL_HOSTNAME}" = "${NEW_HOSTNAME}" ]; then
    verify_check "LocalHostName is ${NEW_HOSTNAME}" "pass"
else
    verify_check "LocalHostName is ${NEW_HOSTNAME} (found: ${CURRENT_LOCAL_HOSTNAME})" "fail"
fi

# ========================================
# 3. HOME DIRECTORY VERIFICATION
# ========================================
log_info "=========================================="
log_info "3. Home Directory Verification"
log_info "=========================================="

EXPECTED_HOME="/Users/${NEW_USERNAME}"
if [ "${HOME}" = "${EXPECTED_HOME}" ]; then
    verify_check "Home directory is ${EXPECTED_HOME}" "pass"
else
    verify_check "Home directory is ${EXPECTED_HOME} (found: ${HOME})" "fail"
fi

if [ -d "${HOME}" ]; then
    verify_check "Home directory exists and is accessible" "pass"
else
    verify_check "Home directory exists and is accessible" "fail"
fi

# Check ownership
HOME_OWNER=$(stat -f "%Su" "${HOME}")
if [ "${HOME_OWNER}" = "${NEW_USERNAME}" ]; then
    verify_check "Home directory owned by ${NEW_USERNAME}" "pass"
else
    verify_check "Home directory owned by ${NEW_USERNAME} (found: ${HOME_OWNER})" "warn"
fi

# ========================================
# 4. CLAUDE CODE VERIFICATION
# ========================================
if [ "${VERIFY_CLAUDE}" = "true" ]; then
    log_info "=========================================="
    log_info "4. Claude Code Verification"
    log_info "=========================================="

    # Check .claude directory
    if [ -d "${HOME}/.claude" ]; then
        verify_check ".claude directory exists" "pass"

        # Check symlinks
        declare -A SYMLINKS=(
            ["agents"]="/Users/${NEW_USERNAME}/.claude-config/agents"
            ["CLAUDE.md"]="/Users/${NEW_USERNAME}/.claude-config/shared/CLAUDE.md"
            ["settings.json"]="/Users/${NEW_USERNAME}/.claude-config/shared/settings.json"
            ["skills"]="/Users/${NEW_USERNAME}/.claude-config/skills"
        )

        for link_name in "${!SYMLINKS[@]}"; do
            expected_target="${SYMLINKS[$link_name]}"

            if [ -L "${HOME}/.claude/${link_name}" ]; then
                actual_target=$(readlink "${HOME}/.claude/${link_name}")
                if [ "${actual_target}" = "${expected_target}" ]; then
                    verify_check "Symlink ${link_name} correct" "pass"
                else
                    verify_check "Symlink ${link_name} correct (target: ${actual_target})" "fail"
                fi

                # Check if target exists
                if [ -e "${expected_target}" ]; then
                    verify_check "Symlink ${link_name} target exists" "pass"
                else
                    verify_check "Symlink ${link_name} target exists" "fail"
                fi
            else
                verify_check "Symlink ${link_name} exists" "fail"
            fi
        done

        # Check for broken symlinks
        BROKEN=$(find "${HOME}/.claude" -type l -exec test ! -e {} \; -print 2>/dev/null | wc -l)
        if [ "${BROKEN}" -eq 0 ]; then
            verify_check "No broken symlinks in .claude" "pass"
        else
            verify_check "No broken symlinks in .claude (found: ${BROKEN})" "fail"
        fi
    else
        verify_check ".claude directory exists" "warn" "false"
    fi

    # Check .claude-config repository
    if [ -d "${HOME}/.claude-config/.git" ]; then
        verify_check ".claude-config repository exists" "pass"

        cd "${HOME}/.claude-config"
        if git status &> /dev/null; then
            verify_check ".claude-config git repository functional" "pass"
        else
            verify_check ".claude-config git repository functional" "fail"
        fi
    else
        verify_check ".claude-config repository exists" "warn" "false"
    fi
else
    log_info "Skipping Claude Code verification (disabled in config)"
fi

# ========================================
# 5. GIT VERIFICATION
# ========================================
if [ "${VERIFY_GIT}" = "true" ]; then
    log_info "=========================================="
    log_info "5. Git Verification"
    log_info "=========================================="

    # Check git config
    if [ -f "${HOME}/.gitconfig" ]; then
        verify_check ".gitconfig exists" "pass"

        GIT_NAME=$(git config user.name 2>/dev/null || echo "")
        GIT_EMAIL=$(git config user.email 2>/dev/null || echo "")

        if [ -n "${GIT_NAME}" ]; then
            verify_check "Git user.name configured (${GIT_NAME})" "pass"
        else
            verify_check "Git user.name configured" "warn" "false"
        fi

        if [ -n "${GIT_EMAIL}" ]; then
            verify_check "Git user.email configured (${GIT_EMAIL})" "pass"
        else
            verify_check "Git user.email configured" "warn" "false"
        fi

        # Check for old username in gitconfig
        if grep -q "/Users/${OLD_USERNAME}" "${HOME}/.gitconfig" 2>/dev/null; then
            verify_check "No old username in .gitconfig" "fail"
        else
            verify_check "No old username in .gitconfig" "pass"
        fi
    else
        verify_check ".gitconfig exists" "warn" "false"
    fi
else
    log_info "Skipping Git verification (disabled in config)"
fi

# ========================================
# 6. SSH VERIFICATION
# ========================================
if [ "${VERIFY_SSH}" = "true" ]; then
    log_info "=========================================="
    log_info "6. SSH Verification"
    log_info "=========================================="

    if [ -d "${HOME}/.ssh" ]; then
        verify_check ".ssh directory exists" "pass"

        # Check SSH directory permissions
        SSH_PERMS=$(stat -f "%p" "${HOME}/.ssh" | tail -c 4)
        if [ "${SSH_PERMS}" = "0700" ]; then
            verify_check ".ssh directory permissions (700)" "pass"
        else
            verify_check ".ssh directory permissions (${SSH_PERMS}, should be 700)" "warn"
        fi

        # Check for SSH keys
        if [ -f "${HOME}/.ssh/id_ed25519" ] || [ -f "${HOME}/.ssh/id_rsa" ]; then
            verify_check "SSH private key exists" "pass"
        else
            verify_check "SSH private key exists" "warn" "false"
        fi

        # Check GitHub SSH connectivity
        log_info "Testing GitHub SSH connection..."
        if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            verify_check "GitHub SSH authentication working" "pass"
        else
            verify_check "GitHub SSH authentication working" "warn" "false"
        fi

        # Check for old username in SSH config
        if [ -f "${HOME}/.ssh/config" ]; then
            if grep -q "/Users/${OLD_USERNAME}" "${HOME}/.ssh/config" 2>/dev/null; then
                verify_check "No old username in SSH config" "fail"
            else
                verify_check "No old username in SSH config" "pass"
            fi
        fi
    else
        verify_check ".ssh directory exists" "warn" "false"
    fi
else
    log_info "Skipping SSH verification (disabled in config)"
fi

# ========================================
# 7. GCLOUD VERIFICATION
# ========================================
if [ "${VERIFY_GCLOUD}" = "true" ]; then
    log_info "=========================================="
    log_info "7. GCloud SDK Verification"
    log_info "=========================================="

    if command -v gcloud &> /dev/null; then
        verify_check "gcloud command available" "pass"

        # Test gcloud functionality
        if gcloud config list &> /dev/null; then
            verify_check "gcloud configuration functional" "pass"
        else
            verify_check "gcloud configuration functional" "warn"
        fi
    else
        verify_check "gcloud command available" "warn" "false"
    fi
else
    log_info "Skipping GCloud verification (disabled in config)"
fi

# ========================================
# 8. SHELL CONFIGURATION VERIFICATION
# ========================================
log_info "=========================================="
log_info "8. Shell Configuration Verification"
log_info "=========================================="

if [ -f "${HOME}/.zshrc" ]; then
    verify_check ".zshrc exists" "pass"

    # Check for old username references
    OLD_REFS=$(grep -c "/Users/${OLD_USERNAME}" "${HOME}/.zshrc" 2>/dev/null || echo "0")
    if [ "${OLD_REFS}" -eq 0 ]; then
        verify_check "No old username in .zshrc" "pass"
    else
        verify_check "No old username in .zshrc (found ${OLD_REFS} references)" "warn"
    fi

    # Check if Anthropic API key is still present
    if grep -q "ANTHROPIC_API_KEY" "${HOME}/.zshrc" 2>/dev/null; then
        verify_check "Anthropic API key present in .zshrc" "pass"
    else
        verify_check "Anthropic API key present in .zshrc" "warn" "false"
    fi
else
    verify_check ".zshrc exists" "warn" "false"
fi

# Check current shell prompt
CURRENT_PROMPT_USER=$(echo $PROMPT | grep -o '%n' &> /dev/null && echo "dynamic" || echo "static")
if [ "${CURRENT_PROMPT_USER}" = "dynamic" ]; then
    verify_check "Shell prompt uses dynamic username" "pass"
else
    verify_check "Shell prompt configuration" "warn" "false"
fi

# ========================================
# FINAL SUMMARY
# ========================================
echo ""
log_info "=========================================="
log_info "VERIFICATION SUMMARY"
log_info "=========================================="
log_info "Total checks: ${TOTAL_CHECKS}"
log_success "Passed: ${PASSED_CHECKS}"
log_warning "Warnings: ${WARNINGS}"
log_error "Failed: ${FAILED_CHECKS}"
log_info "=========================================="

# Generate verification score
if [ "${TOTAL_CHECKS}" -gt 0 ]; then
    SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    log_info "Verification Score: ${SCORE}%"
fi

echo ""

# Final verdict
if [ "${FAILED_CHECKS}" -eq 0 ]; then
    if [ "${WARNINGS}" -eq 0 ]; then
        log_success "=========================================="
        log_success "✅ MIGRATION VERIFIED SUCCESSFULLY"
        log_success "=========================================="
        log_info ""
        log_info "All verification checks passed!"
        log_info "Your system is ready to use."
        log_info ""
        log_info "Final steps:"
        log_info "1. Delete temporary admin account (tempadmin)"
        log_info "2. Update remote machines' known_hosts"
        log_info "3. Test remote SSH/screen sharing"
        log_info "4. Keep backup for 30 days: ${BACKUP_ROOT}"
        exit 0
    else
        log_warning "=========================================="
        log_warning "⚠️  MIGRATION VERIFIED WITH WARNINGS"
        log_warning "=========================================="
        log_info ""
        log_info "Core functionality verified, but some issues found."
        log_info "Review warnings above and fix if necessary."
        log_info "Log file: ${LOG_FILE}"
        exit 0
    fi
else
    log_error "=========================================="
    log_error "❌ MIGRATION VERIFICATION FAILED"
    log_error "=========================================="
    log_error ""
    log_error "${FAILED_CHECKS} critical check(s) failed!"
    log_error "Review errors above and run post-migration-fix.sh again."
    log_error "Log file: ${LOG_FILE}"
    log_error ""
    log_error "To restore from backup:"
    log_error "  ${BACKUP_ROOT}/restore-backup.sh"
    exit 1
fi
