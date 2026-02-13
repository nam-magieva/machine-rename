# Automated Migration Guide

**Version:** 2.3.0 - Maximum Automation with Safety Guardrails

---

## 🎯 **ONE SCRIPT TO RULE THEM ALL**

We've automated **everything that can be safely automated**. You'll only need to:
1. Run **one script**
2. Click through **a few confirmations**
3. Follow **simple instructions** for the parts that require logout/login

---

## 🚀 **QUICK START (Automated)**

```bash
cd ~/machine-rename

# Run the automated migration script
./automated-migration.sh --name=minionkevin --host=minion-kevin --fullname="Minion Kevin"
```

**Options:**
- `--name=USERNAME` - New username (required)
- `--host=HOSTNAME` - New hostname (required)
- `--fullname=NAME` - New display name shown on login screen (optional)
- `--skip-backup` - Skip backup phase when retrying a failed migration
- `--old-name=USERNAME` - Override old username detection (for retry scenarios)
- `--dry-run` - Test without making changes

**What it automates:**
- ✅ Full backup with pre-flight checks (10 min)
- ✅ Hostname change (instant)
- ✅ Creates temporary admin account with password `123456` (instant)
- ✅ Generates user rename script (instant)
- ✅ Creates detailed instructions (instant)
- ✅ Offers to log you out automatically

**What you still click:**
- Confirm you understand warnings (1 click)
- Confirm hostname change (1 click)
- Confirm temp admin creation (1 click)
- Confirm logout (1 click)

---

## 📋 **WHAT HAPPENS STEP-BY-STEP**

### **Phase 0: Safety Checks (Automated)**
✅ Verifies you're running as the correct user
✅ Checks you're not in an SSH session (would disconnect)
✅ Verifies you have admin privileges
✅ Checks if temp admin already exists

### **Phase 1: Backup (Automated - 10 min)**
✅ Runs full pre-migration backup
✅ Pre-flight checks (disk space, network, etc.)
✅ Creates restoration script
*(Skip with `--skip-backup` when retrying)*

### **Phase 2: Hostname Change (Automated with 1 confirmation)**
✅ Changes ComputerName, LocalHostName, HostName
✅ Flushes DNS cache
✅ Verifies change succeeded

### **Phase 3: Create Temp Admin (Automated with 1 confirmation)**
✅ Creates `tempadmin` account with password `123456`
✅ Adds to admin group
✅ Creates home directory
✅ Saves credentials to file
✅ If tempadmin already exists: resets password to `123456`

### **Phase 4: Prepare Rename Script (Automated)**
✅ Creates `/Users/tempadmin/rename-user.sh`
✅ Sets correct permissions
✅ Includes safety checks and rollback logic
✅ Detects and recovers from previous failed attempts

### **Phase 5: Generate Instructions (Automated)**
✅ Creates `MIGRATION-INSTRUCTIONS.txt`
✅ Opens file automatically
✅ Offers to log you out

### **Phase 6-8: Manual Steps (Guided - 15 min)**

**You do these (script can't automate logout/login):**

**Step 6:** Log out (or script does it for you if you confirm)

**Step 7:** Log in as `tempadmin`
- Username: `tempadmin`
- Password: `123456`

**Step 8:** Run rename script:
```bash
~/rename-user.sh
```

The rename script:
1. Updates NFSHomeDirectory in Directory Services
2. Strips ACL and renames home directory (instant `mv`, no copying)
3. Renames user account (RecordName)
4. Fixes ownership and restores ACL
5. Creates compatibility symlink (old path still works)
6. Updates display name (if `--fullname` was provided)

**Step 9:** Log out of tempadmin

**Step 10:** Log in as new username
- Username: `minionkevin` (the new name)
- Password: (your SAME old password)

**Step 11:** Run post-migration fixes (automated):
```bash
cd ~/machine-rename
./post-migration-fix.sh --name=minionkevin --host=minion-kevin --fullname="Minion Kevin"
```

**Step 12:** Run verification (automated):
```bash
./verify-migration.sh --name=minionkevin --host=minion-kevin
```

**Step 13:** Delete temp admin (via System Preferences)

---

## 🛡️ **SAFETY GUARDRAILS BUILT-IN**

### **Pre-Execution Checks:**
- ❌ Blocks if running in SSH session (would disconnect)
- ❌ Blocks if not running as correct user
- ❌ Blocks if user doesn't have admin privileges
- ✅ Warns if temp admin already exists (resets password)

### **Confirmation Checkpoints:**
- ⚠️ Displays critical warnings before starting
- ⚠️ Requires confirmation for hostname change
- ⚠️ Requires confirmation for temp admin creation
- ⚠️ Requires typing 'yes' in rename script

### **Rename Script Safety:**
- ✅ Detects current state (supports retrying after failures)
- ✅ Must be run as temp admin (not target user)
- ✅ Verifies old user is not logged in
- ✅ Detects and cleans up partial copies from failed attempts
- ✅ Strips ACL before `mv` (fixes "Operation not permitted")
- ✅ Strips file flags if present (`chflags`)
- ✅ Rollback on failure (each step undoes previous steps)
- ✅ Requires typing 'yes' to proceed

### **Rollback Capability:**
- ✅ Full backup created before any changes
- ✅ Automated restoration script available
- ✅ Detailed logs of all operations

---

## ⏱️ **ACTUAL TIMELINE**

| Phase | Type | Time | What Happens |
|-------|------|------|--------------|
| 0-5 | **Automated** | 12 min | Script runs, you click 4 confirmations |
| 6 | **Manual** | 10 sec | Log out |
| 7 | **Manual** | 30 sec | Log in as tempadmin |
| 8 | **Automated** | instant | Run ~/rename-user.sh, type 'yes' once |
| 9 | **Manual** | 10 sec | Log out |
| 10 | **Manual** | 30 sec | Log in as new user |
| 11 | **Automated** | 5 min | Run post-migration-fix.sh |
| 12 | **Automated** | 3 min | Run verify-migration.sh |
| 13 | **Manual** | 2 min | Delete tempadmin via System Prefs |

**Total:** ~25 minutes (18 min automated, 7 min manual clicks)

---

## 🚨 **IF SOMETHING GOES WRONG**

### **"Operation not permitted" on mv**
The rename script handles this automatically by stripping ACLs and file flags.
If it still fails, grant Full Disk Access to Terminal:
- System Settings → Privacy & Security → Full Disk Access → enable Terminal.app
- Restart Terminal and re-run

### **Login hangs after rename**
Log in as tempadmin and fix ownership:
```bash
sudo chown -R minionkevin:staff /Users/minionkevin
sudo chmod +a "group:everyone deny delete" /Users/minionkevin
```

### **"User already exists" / "Directory already exists"**
This means a previous attempt partially completed. Use `--skip-backup`:
```bash
./automated-migration.sh --name=minionkevin --host=minion-kevin --skip-backup
```
The rename script detects partial state and picks up where it left off.

### **Display name still shows old name**
Run from your new account:
```bash
sudo dscl . -create /Users/minionkevin RealName "Minion Kevin"
```
Or re-run post-migration with `--fullname`:
```bash
./post-migration-fix.sh --name=minionkevin --host=minion-kevin --fullname="Minion Kevin"
```

### **Nested home directory (~/oldname inside home)**
The `mv` moved the folder inside instead of renaming. From tempadmin:
```bash
sudo mv /Users/newname/oldname /Users/oldname-temp
sudo rm -rf /Users/newname
sudo mv /Users/oldname-temp /Users/newname
sudo chown -R newname:staff /Users/newname
sudo chmod +a "group:everyone deny delete" /Users/newname
```

### **"Must run as user" error after dscl rename**
`whoami` returns the new name after dscl changes. Use `--old-name`:
```bash
./automated-migration.sh --name=minionkevin --host=minion-kevin --old-name=minione --skip-backup
```

### **Forgot temp admin password**
Password is always `123456`. Or re-run the script to reset it.

### **Remote Desktop asks for permission every time**
Migration reset per-user sharing permissions. Run:
```bash
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -configure -allowAccessFor -allUsers -privs -all
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -restart
```

---

## 🎯 **RECOMMENDED WORKFLOW**

### **For Multiple Machines:**

**Machine 1 (First run):**
```bash
./automated-migration.sh --name=minionstuart --host=minion-stuart --fullname="Minion Stuart"
# Follow instructions...
./post-migration-fix.sh --name=minionstuart --host=minion-stuart --fullname="Minion Stuart"
./verify-migration.sh --name=minionstuart --host=minion-stuart
```

**Machine 2 & 3:**
```bash
cd ~/machine-rename && git pull
./automated-migration.sh --name=minionkevin --host=minion-kevin --fullname="Minion Kevin"
./automated-migration.sh --name=minionbob --host=minion-bob --fullname="Minion Bob"
```

---

## 📝 **FILES CREATED**

After running `automated-migration.sh`, you'll find:

```
~/migration-credentials.txt       - Temp admin password (DELETE after)
~/MIGRATION-INSTRUCTIONS.txt      - Step-by-step guide
/Users/tempadmin/rename-user.sh   - User rename script
/tmp/migration-backup-*/          - Full backup
~/migration-log-*.txt             - Detailed logs
```

---

**Ready to migrate? Run:**
```bash
./automated-migration.sh --name=minionkevin --host=minion-kevin --fullname="Minion Kevin"
```
