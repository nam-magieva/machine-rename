# Machine Rename - Username & Hostname Migration

**Version:** 2.2.0 - **NEW: Fully Automated!**
**Time Required:** ~25 min (90% automated)

---

## ⚡ **NEW: ONE-SCRIPT AUTOMATION**

We've automated **90% of the migration!** Just run one command and follow simple instructions.

```bash
cd ~/machine-rename
./automated-migration.sh --name=minionkevin --host=minion-kevin
```

**What it automates:**
- ✅ Full backup with validation (10 min)
- ✅ Hostname change (instant)
- ✅ Creates temp admin account (instant)
- ✅ Generates rename script (instant)
- ✅ Detailed instructions (instant)
- ✅ Auto-logout option (instant)

**What you do:**
- Click 4 confirmations
- Log out / log in (3 times)
- Run 2 scripts
- **Total: 7 minutes of clicking**

**Read the full guide:** [AUTOMATED-GUIDE.md](AUTOMATED-GUIDE.md)

---

## 🎯 **CHOOSE YOUR PATH**

### **Option 1: Automated (Recommended) - 25 min**
```bash
./automated-migration.sh --name=minionkevin --host=minion-kevin
```
**Best for:** Most users, first-time migration, multiple machines

### **Option 2: Manual - 50 min**
```bash
./pre-migration-v2.sh --name=minionkevin --host=minion-kevin
# ... manual System Preferences steps ...
./post-migration-fix.sh --name=minionkevin --host=minion-kevin
./verify-migration.sh --name=minionkevin --host=minion-kevin
```
**Best for:** Advanced users who want full control

---

## 📖 **COMMAND-LINE USAGE**

### **Required Arguments:**
- `--name=USERNAME` - New username (lowercase alphanumeric)
- `--host=HOSTNAME` - New hostname (lowercase with hyphens)

### **Optional Arguments:**
- `--machine-id=ID` - Machine identifier (auto-derived from hostname)
- `--dry-run` - Test without making changes
- `--help` or `-h` - Show help message

### **Examples:**

**Stuart's machine:**
```bash
./automated-migration.sh --name=minionstuart --host=minion-stuart
```

**Kevin's machine:**
```bash
./automated-migration.sh --name=minionkevin --host=minion-kevin
```

**Bob's machine:**
```bash
./automated-migration.sh --name=minionbob --host=minion-bob
```

**Any custom name:**
```bash
./automated-migration.sh --name=johndoe --host=johns-macbook
```

**Test first (dry-run):**
```bash
./automated-migration.sh --name=minionkevin --host=minion-kevin --dry-run
```

---

## 📁 **FILES IN THIS FOLDER**

### **Main Scripts (Use These):**
```
automated-migration.sh      - NEW! One script for everything
pre-migration-v2.sh         - Backup with validation (called by automated)
post-migration-fix.sh       - Fix symlinks & paths (run after rename)
verify-migration.sh         - Verify success (run last)
```

### **Configuration:**
```
migration-config-v2.sh      - Config (auto-loaded, no editing needed!)
```

### **Documentation:**
```
README.md                   - This file
AUTOMATED-GUIDE.md          - Complete automation guide
CHEATSHEET.txt              - Quick reference
MIGRATION-IMPROVEMENTS.md   - What changed in v2.1/v2.2
```

---

## 🚀 **QUICK START (Automated Method)**

### **Step 1: Run Automated Script**
```bash
cd ~/machine-rename
./automated-migration.sh --name=minionkevin --host=minion-kevin
```

**Script will:**
- ✅ Run full backup with pre-flight checks
- ✅ Change hostname automatically
- ✅ Create temporary admin account
- ✅ Generate user rename script
- ✅ Show you credentials and instructions
- ✅ Offer to log you out

**You click:** 4 confirmations, then follow instructions

---

### **Step 2: Follow Auto-Generated Instructions**

The script creates `~/MIGRATION-INSTRUCTIONS.txt` with:
1. Log out (or script does it for you)
2. Log in as `tempadmin` (password shown)
3. Run `~/rename-user.sh` (type 'yes' once)
4. Log out of tempadmin
5. Log in as new username (same old password)
6. Run post-migration fix script
7. Run verification script
8. Delete tempadmin (System Preferences)

**Total time: 7 minutes of clicking**

---

## ⏱️ **TIMELINE COMPARISON**

| Method | Total Time | Your Active Work |
|--------|-----------|------------------|
| **Automated (new)** | **25 min** | **7 min** ✅ |
| Manual (old) | 50 min | 50 min |

**50% faster, 86% less work!**

---

## 📊 **WHAT GETS BACKED UP**

- SSH config and keys (`~/.ssh/`)
- Git global config (`~/.gitconfig`)
- Shell configs (`.zshrc`, `.zprofile`, etc.)
- Claude Code config (`~/.claude/`, `~/.claude-config/`)
- GCloud SDK config (`~/.config/gcloud/`)
- Docker config (`~/.docker/`)
- Editor configs (Cursor, VS Code)
- LaunchAgent plists
- Git repository list
- System state snapshot

**Backup location:** `/tmp/migration-backup-MACHINE_ID/`

---

## 🔧 **WHAT GETS FIXED AUTOMATICALLY**

Post-migration script handles:
- ✅ Claude Code symlinks (agents, CLAUDE.md, settings, skills)
- ✅ LaunchAgent plists (auto-updated and reloaded)
- ✅ Claude Code `.claude.json` (all project paths)
- ✅ GCloud virtualenv (removed and recreated)
- ✅ Docker configs (paths updated, cache cleaned)
- ✅ File ownership (entire home directory)
- ✅ SSH permissions (700 for .ssh, 600 for keys)
- ✅ Shell configurations (hardcoded paths)
- ✅ Claude cache (cleaned and regenerated)

---

## ✅ **PRE-FLIGHT CHECKS**

Before backup, the script validates:

| Check | Purpose |
|-------|---------|
| Current user | Must run as old username |
| SSH session | Blocks if in SSH (would disconnect) |
| Admin privileges | Must be admin |
| Target available | New username must not exist |
| Disk space | Need 20GB minimum |
| Network | Check hostname conflicts |
| Running apps | Warn about Docker, Claude, etc. |
| Git changes | Warn about uncommitted changes |

---

## 🛡️ **SAFETY FEATURES**

### **Built-in Guardrails:**
- ❌ Blocks SSH sessions (unsafe - would disconnect)
- ✅ Verifies running as correct user
- ✅ Checks admin privileges
- ✅ Multiple confirmation checkpoints
- ✅ Validates all conditions before starting
- ✅ Full backup before ANY changes
- ✅ Automated rollback available

### **Rename Script Safety:**
- ✅ Must run as temp admin
- ✅ Verifies target user not logged in
- ✅ Checks new username doesn't exist
- ✅ Validates home directory state
- ✅ Requires typing 'yes' to proceed

---

## 🆘 **TROUBLESHOOTING**

### **"ERROR: NEW_USERNAME not set"**
```bash
# Missing arguments - use command-line args:
./automated-migration.sh --name=minionkevin --host=minion-kevin
```

### **"You are in an SSH session"**
Script blocks SSH for safety. Use:
- Physical console
- Screen sharing
- Local Terminal

### **Pre-flight fails with "insufficient disk space"**
```bash
# Check usage
df -h /Users

# Free up space or skip check (advanced)
```

### **"Temporary admin already exists"**
From previous run. Either:
- Continue anyway (script handles it)
- Delete first: `sudo dscl . -delete /Users/tempadmin`

### **Need to rollback**
```bash
# Automated restoration
/tmp/migration-backup-MACHINE_ID/restore-backup.sh
```

### **Forgot temp admin password**
```bash
cat ~/migration-credentials.txt
```

---

## 🎯 **MULTIPLE MACHINES**

Run on each machine with different arguments:

**Machine 1 - Stuart:**
```bash
./automated-migration.sh --name=minionstuart --host=minion-stuart
# ... follow instructions ...
```

**Machine 2 - Kevin:**
```bash
# Copy scripts from Stuart
scp minionstuart@minion-stuart.local:~/machine-rename/*.sh ~/machine-rename/

# Run with Kevin's identity
./automated-migration.sh --name=minionkevin --host=minion-kevin
# ... follow instructions ...
```

**Machine 3 - Bob:**
```bash
./automated-migration.sh --name=minionbob --host=minion-bob
# ... follow instructions ...
```

---

## 💡 **PRO TIPS**

1. **Test with dry-run first**
   ```bash
   ./automated-migration.sh --name=NAME --host=HOST --dry-run
   ```

2. **Use physical access** (not SSH during migration)

3. **Close all applications** before starting

4. **Commit git changes** before backup

5. **Keep backups 30 days** before deleting

6. **Document your command:**
   ```bash
   echo "./automated-migration.sh --name=minionkevin --host=minion-kevin" > ~/my-command.txt
   ```

7. **Run on test machine first** before production machines

---

## 🚨 **CRITICAL WARNINGS**

### **WILL BREAK:**
- ❌ Active SSH sessions (disconnect immediately)
- ❌ Screen sharing (disconnect immediately)
- ❌ Apps using username/hostname
- ❌ Open applications (will be closed)

### **PRESERVED:**
- ✅ All files (moved with home directory)
- ✅ Git repos (including history)
- ✅ SSH keys (GitHub auth continues)
- ✅ Claude Code (after fix script)
- ✅ Application data

### **REQUIRES:**
- ✅ Physical/console access (not SSH)
- ✅ Admin password
- ✅ 20GB+ free disk space
- ✅ 25 minutes uninterrupted time

---

## ✅ **SUCCESS CHECKLIST**

After migration:
- [ ] `whoami` → correct username
- [ ] `hostname` → correct hostname
- [ ] `pwd` at home → `/Users/NEW_USERNAME`
- [ ] `claude --version` → works
- [ ] `cd ~/.claude-config && git status` → works
- [ ] `ssh -T git@github.com` → authenticated
- [ ] `find ~/.claude -type l -exec test ! -e {} \; -print` → empty (no broken symlinks)
- [ ] Remote SSH works
- [ ] Verification script passes 100%

---

## 📞 **GET HELP**

```bash
# Show usage
./automated-migration.sh --help

# Check what would happen
./automated-migration.sh --name=NAME --host=HOST --dry-run

# View detailed guide
cat AUTOMATED-GUIDE.md
```

---

## 📊 **WHAT'S NEW**

### **v2.2.0 (Current) - Automated Migration**
✨ **One-script automation** - 90% automated, 50% faster
- Automated hostname change
- Automated temp admin creation
- Auto-generated rename script with safety checks
- Auto-generated instructions
- Auto-logout option
- Built-in SSH detection
- **25 minutes total (7 min active work)**

### **v2.1.0 - Command-Line Arguments**
- Added `--name` and `--host` arguments
- No more editing config files
- Dynamic machine ID from hostname
- Dry-run mode support

### **v2.0.0 - Comprehensive Fixes**
- LaunchAgent plist fixes
- Claude Code `.claude.json` fixes
- GCloud virtualenv recreation
- Docker config updates
- Cache cleanup
- **Based on 500+ file audit**

---

## 🎓 **DOCUMENTATION**

- **[AUTOMATED-GUIDE.md](AUTOMATED-GUIDE.md)** - Complete automation guide
- **[CHEATSHEET.txt](CHEATSHEET.txt)** - Quick reference
- **[MIGRATION-IMPROVEMENTS.md](MIGRATION-IMPROVEMENTS.md)** - Technical review

---

## 🌟 **FEATURES**

✅ Command-line arguments (no file editing)
✅ 90% automated with guardrails
✅ Pre-flight validation (10 checks)
✅ Automated backup with system snapshot
✅ Automated hostname change
✅ Automated temp admin creation
✅ Safe user rename script generation
✅ Post-migration fixes (LaunchAgents, Claude, Docker, GCloud)
✅ Comprehensive verification (20+ checks)
✅ Dry-run mode for testing
✅ Idempotent (safe to re-run)
✅ Network hostname conflict detection
✅ SSH session blocking (prevents disconnect)
✅ Support for any custom username/hostname
✅ Detailed logging and rollback

---

**Ready to migrate?**
```bash
cd ~/machine-rename
./automated-migration.sh --name=YOUR_USERNAME --host=YOUR_HOSTNAME
```

**Questions? Read:** [AUTOMATED-GUIDE.md](AUTOMATED-GUIDE.md)

**GitHub:** https://github.com/nam-magieva/machine-rename

**Good luck! 🚀**
