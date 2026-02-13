# Machine Rename - Username & Hostname Migration

**Version:** 2.1.0 (Command-Line Args Support!)
**Time Required:** ~50 min per machine

---

## 🎯 **USE ANY NAMES YOU WANT**

The scripts now accept **command-line arguments** - no more editing config files!

**Examples:**
```bash
# Stuart's machine
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart

# Kevin's machine
./pre-migration-v2.sh --name=minionkevin --host=minion-kevin

# Bob's machine
./pre-migration-v2.sh --name=minionbob --host=minion-bob

# Or ANY custom name you want!
./pre-migration-v2.sh --name=johndoe --host=johns-macbook
./pre-migration-v2.sh --name=devmachine --host=dev-workstation
```

---

## 🚀 **QUICK START (3 Commands)**

```bash
cd ~/machine-rename

# Run with your desired username and hostname
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart

# Follow manual steps (hostname & username change)...

# Then run post-migration fixes
./post-migration-fix.sh --name=minionstuart --host=minion-stuart

# Verify everything works
./verify-migration.sh --name=minionstuart --host=minion-stuart
```

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

**Basic usage:**
```bash
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart
```

**Test first (dry-run):**
```bash
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart --dry-run
```

**Custom machine ID:**
```bash
./pre-migration-v2.sh --name=johndoe --host=johns-mac --machine-id=john
```

**Show help:**
```bash
./pre-migration-v2.sh --help
```

---

## 📁 **FILES IN THIS FOLDER**

```
migration-config-v2.sh      - Config (auto-loaded, no editing needed!)
pre-migration-v2.sh         - Backup with validation (run first)
post-migration-fix.sh       - Fix symlinks & paths (run after)
verify-migration.sh         - Verify success (run last)
README.md                   - This file
MIGRATION-IMPROVEMENTS.md   - What changed in v2.1
CHEATSHEET.txt              - One-page quick reference
```

---

## 🔧 **COMPLETE WORKFLOW**

### **Step 1: Pre-Migration Backup (10 min)**
```bash
cd ~/machine-rename
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart
```

**What it does:**
- ✅ Pre-flight checks (disk space, network, availability)
- ✅ Backs up SSH, Git, Claude Code, Docker configs
- ✅ Creates system state snapshot
- ✅ Generates restoration script

### **Step 2: Hostname Change (2 min - Manual)**
```bash
sudo scutil --set ComputerName "minion-stuart"
sudo scutil --set LocalHostName "minion-stuart"
sudo scutil --set HostName "minion-stuart"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### **Step 3: Username Change (30 min - Manual via System Preferences)**

**Create temporary admin:**
1. System Preferences → Users & Groups
2. Create user: `tempadmin` (administrator)
3. Log out, log in as `tempadmin`

**Rename user account:**
1. System Preferences → Users & Groups (as tempadmin)
2. Right-click `minione` → Advanced Options
3. Change **Account name:** `minionstuart`
4. Change **Home directory:** `/Users/minionstuart`
5. Click OK

**Rename home directory:**
```bash
sudo mv /Users/minione /Users/minionstuart
sudo chown -R minionstuart:staff /Users/minionstuart
```

**Test new account:**
1. Log out of tempadmin
2. Log in as `minionstuart`
3. Verify: `whoami` → `minionstuart`

### **Step 4: Post-Migration Fixes (5 min)**
```bash
cd ~/machine-rename
./post-migration-fix.sh --name=minionstuart --host=minion-stuart
```

**What it fixes:**
- Claude Code symlinks (agents, CLAUDE.md, settings, skills)
- File ownership
- SSH permissions
- Hardcoded paths
- GCloud SDK (reinstall if needed)

### **Step 5: Verification (3 min)**
```bash
./verify-migration.sh --name=minionstuart --host=minion-stuart
```

**What it checks:**
- Username & hostname correct
- Home directory accessible
- Claude Code working
- Git repositories intact
- SSH keys present
- GitHub authentication working
- No broken symlinks

### **Step 6: Cleanup**
- Delete `tempadmin` account (System Preferences)
- Update SSH known_hosts on remote machines:
  ```bash
  # On other machines:
  ssh-keygen -R mini-one.local
  ssh minionstuart@minion-stuart.local  # Accept new key
  ```

---

## ⚡ **DRY-RUN MODE**

Test without making any changes:
```bash
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart --dry-run
```

Output shows what would happen:
```
[DRY RUN] Would execute: rsync -av ~/.ssh/ /tmp/backup/ssh/
[DRY RUN] Would execute: mkdir -p /tmp/backup
```

---

## 📊 **WHAT GETS BACKED UP**

- SSH config and keys (`~/.ssh/`)
- Git global config (`~/.gitconfig`)
- Shell configs (`.zshrc`, `.zprofile`, etc.)
- Claude Code config (`~/.claude/`, `~/.claude-config/`)
- GCloud SDK config (`~/.config/gcloud/`)
- Docker config (`~/.docker/`)
- Editor configs (Cursor, VS Code)
- Git repository list
- System state snapshot

**Backup location:** `/tmp/migration-backup-MACHINE_ID/`

---

## ✅ **PRE-FLIGHT CHECKS**

Before backup, the script validates:

| Check | Purpose |
|-------|---------|
| Current user | Must run as old username |
| Target available | New username must not exist |
| Disk space | Need 2x home size + 1GB |
| Network | Check hostname conflicts |
| Running apps | Warn about Docker, Claude, etc. |
| Git changes | Warn about uncommitted changes |
| Required tools | rsync, git, ssh, scutil present |

---

## 🆘 **TROUBLESHOOTING**

### **"ERROR: NEW_USERNAME not set"**
```bash
# Missing arguments - use command-line args:
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart
```

### **Pre-flight fails with "insufficient disk space"**
```bash
# Check usage
du -sh ~

# Free up space or use external drive
# Edit migration-config-v2.sh and change BACKUP_ROOT
```

### **Pre-flight fails with "hostname already exists"**
```bash
# Check network
ping -c 1 minion-stuart.local

# If responds: choose different hostname
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart-2
```

### **Script fails midway**
```bash
# Safe to re-run (idempotent)
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart
```

### **Need to rollback**
```bash
# Automated restoration
/tmp/migration-backup-stuart/restore-backup.sh
```

### **Symlinks still broken**
```bash
# Re-run fix script (idempotent)
./post-migration-fix.sh --name=minionstuart --host=minion-stuart
```

### **Verification fails**
```bash
# Check log
cat ~/migration-log-stuart.txt | grep "FAIL"

# Fix manually, then re-verify
./verify-migration.sh --name=minionstuart --host=minion-stuart
```

---

## 🎯 **MULTIPLE MACHINES**

Run on each machine with different arguments:

**Machine 1 - Stuart:**
```bash
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart
# ... follow manual steps ...
./post-migration-fix.sh --name=minionstuart --host=minion-stuart
./verify-migration.sh --name=minionstuart --host=minion-stuart
```

**Machine 2 - Kevin:**
```bash
# Copy scripts from Stuart
scp minionstuart@minion-stuart.local:~/machine-rename/*.sh ~/machine-rename/

# Run with Kevin's identity
./pre-migration-v2.sh --name=minionkevin --host=minion-kevin
# ... follow manual steps ...
./post-migration-fix.sh --name=minionkevin --host=minion-kevin
./verify-migration.sh --name=minionkevin --host=minion-kevin
```

**Machine 3 - Bob:**
```bash
# Same process with Bob's identity
./pre-migration-v2.sh --name=minionbob --host=minion-bob
# ... follow manual steps ...
./post-migration-fix.sh --name=minionbob --host=minion-bob
./verify-migration.sh --name=minionbob --host=minion-bob
```

---

## 💡 **PRO TIPS**

1. **Test with dry-run first**
   ```bash
   ./pre-migration-v2.sh --name=NAME --host=HOST --dry-run
   ```

2. **Use physical access** (not SSH during migration)

3. **Close all applications** before starting

4. **Commit git changes** before backup

5. **Keep backups 30 days** before deleting

6. **Document your command** for reference:
   ```bash
   echo "./pre-migration-v2.sh --name=minionstuart --host=minion-stuart" > ~/my-migration-command.txt
   ```

---

## 🚨 **CRITICAL WARNINGS**

### **WILL BREAK:**
- ❌ Active SSH sessions (disconnect immediately)
- ❌ Screen sharing (disconnect immediately)
- ❌ Apps using username/hostname

### **PRESERVED:**
- ✅ All files (moved with home directory)
- ✅ Git repos (including history)
- ✅ SSH keys (GitHub auth continues)
- ✅ Claude Code (after fix script)

### **REQUIRES:**
- ✅ Physical/console access
- ✅ Admin password
- ✅ 2x home directory disk space
- ✅ 30-60 minutes uninterrupted time

---

## ✅ **SUCCESS CHECKLIST**

After migration:
- [ ] `whoami` → correct username
- [ ] `hostname` → correct hostname
- [ ] `pwd` at home → `/Users/NEW_USERNAME`
- [ ] `claude --version` → works
- [ ] `cd ~/.claude-config && git status` → works
- [ ] `ssh -T git@github.com` → authenticated
- [ ] `find ~/.claude -type l -exec test ! -e {} \; -print` → empty
- [ ] Remote SSH works
- [ ] Verification script passes 100%

---

## 📞 **GET HELP**

```bash
# Show usage
./pre-migration-v2.sh --help

# Test configuration
./migration-config-v2.sh --name=minionstuart --host=minion-stuart

# Check what would happen
./pre-migration-v2.sh --name=NAME --host=HOST --dry-run
```

---

## 📊 **TIMELINE**

| Phase | Duration | Type |
|-------|----------|------|
| Pre-flight + Backup | 10 min | Automated |
| Hostname change | 2 min | Manual |
| Username change | 30 min | Manual |
| Post-fixes | 5 min | Automated |
| Verification | 3 min | Automated |
| **Total** | **50 min** | |

---

## 🎓 **WHAT'S NEW IN v2.1**

✨ **Command-line arguments!** No more editing config files!

**Before (v2.0):**
```bash
vim migration-config-v2.sh  # Edit file, uncomment section
./pre-migration-v2.sh        # Run
```

**Now (v2.1):**
```bash
./pre-migration-v2.sh --name=minionstuart --host=minion-stuart
```

**Benefits:**
- ✅ No file editing needed
- ✅ Works with ANY name (not just Stuart/Kevin/Bob)
- ✅ Easier to script and automate
- ✅ Copy-paste commands between machines
- ✅ Test with `--dry-run` flag

---

**Ready to start?**
```bash
cd ~/machine-rename
./pre-migration-v2.sh --name=YOUR_USERNAME --host=YOUR_HOSTNAME
```

**Good luck! 🚀**
