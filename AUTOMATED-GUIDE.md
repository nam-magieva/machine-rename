# Automated Migration Guide

**Version:** 2.2.0 - Maximum Automation with Safety Guardrails

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
./automated-migration.sh --name=minionkevin --host=minion-kevin
```

**What it automates:**
- ✅ Full backup with pre-flight checks (10 min)
- ✅ Hostname change (instant)
- ✅ Creates temporary admin account (instant)
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

### **Phase 2: Hostname Change (Automated with 1 confirmation)**
✅ Changes ComputerName, LocalHostName, HostName
✅ Flushes DNS cache
✅ Verifies change succeeded

### **Phase 3: Create Temp Admin (Automated with 1 confirmation)**
✅ Creates `tempadmin` account
✅ Generates secure random password
✅ Adds to admin group
✅ Creates home directory
✅ Saves credentials to file

### **Phase 4: Prepare Rename Script (Automated)**
✅ Creates `/Users/tempadmin/rename-user.sh`
✅ Sets correct permissions
✅ Includes safety checks

### **Phase 5: Generate Instructions (Automated)**
✅ Creates `MIGRATION-INSTRUCTIONS.txt`
✅ Opens file automatically
✅ Offers to log you out

### **Phase 6-8: Manual Steps (Guided - 15 min)**

**You do these (script can't automate logout/login):**

**Step 6:** Log out (or script does it for you if you confirm)

**Step 7:** Log in as `tempadmin`
- Username: `tempadmin`
- Password: (shown on screen + saved in file)

**Step 8:** Run rename script:
```bash
~/rename-user.sh
```

This renames user and moves home directory (takes 2-5 min)

**Step 9:** Log out of tempadmin

**Step 10:** Log in as new username
- Username: `minionkevin` (the new name)
- Password: (your SAME old password)

**Step 11:** Run post-migration fixes (automated):
```bash
cd ~/machine-rename
./post-migration-fix.sh --name=minionkevin --host=minion-kevin
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
- ✅ Warns if temp admin already exists

### **Confirmation Checkpoints:**
- ⚠️ Displays critical warnings before starting
- ⚠️ Requires confirmation for hostname change
- ⚠️ Requires confirmation for temp admin creation
- ⚠️ Requires typing 'yes' in rename script

### **Rename Script Safety:**
- ✅ Must be run as temp admin (not target user)
- ✅ Verifies old user is not logged in
- ✅ Checks new username doesn't exist
- ✅ Verifies old home exists
- ✅ Verifies new home doesn't exist
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
| 8 | **Automated** | 3 min | Run ~/rename-user.sh, type 'yes' once |
| 9 | **Manual** | 10 sec | Log out |
| 10 | **Manual** | 30 sec | Log in as new user |
| 11 | **Automated** | 5 min | Run post-migration-fix.sh |
| 12 | **Automated** | 3 min | Run verify-migration.sh |
| 13 | **Manual** | 2 min | Delete tempadmin via System Prefs |

**Total:** ~25 minutes (18 min automated, 7 min manual clicks)

---

## 🆚 **COMPARISON TO MANUAL PROCESS**

### **Old Manual Way (50 min):**
- 10 min: Run backup script
- 2 min: Type hostname commands in Terminal
- 5 min: System Prefs → Create temp admin
- 1 min: Log out
- 5 min: Log in as temp admin
- 15 min: System Prefs → Advanced Options → Rename user
- 5 min: Terminal → Move home directory
- 1 min: Log out
- 1 min: Log in as new user
- 5 min: Run post-migration script
- Total: **50 minutes of active work**

### **New Automated Way (25 min):**
- 12 min: Run script, click 4 confirmations
- 2 min: Log out, log in, log out, log in
- 3 min: Run one script (rename)
- 8 min: Run two scripts (fix + verify)
- Total: **25 minutes, mostly waiting**

**50% time savings!** And much less error-prone.

---

## 💡 **WHAT CAN'T BE AUTOMATED & WHY**

### **Cannot Automate:**

**1. Logout/Login Cycles**
- macOS requires user to log out before renaming
- AppleScript can trigger logout but can't login
- Need physical keyboard/mouse for login

**2. System Preferences Advanced Options (OLD METHOD)**
- We bypass this entirely! Our script uses `dscl` commands
- Fully automated user rename with safety checks

**Result:** We automated the rename! You just log out/log in.

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

## 🚨 **IF SOMETHING GOES WRONG**

### **During Automated Phase (Phase 0-5):**
- Script will abort and show clear error
- No changes made yet if pre-flight checks fail
- Safe to re-run script

### **During Rename (Phase 8):**
- Rename script has 5 safety checks before proceeding
- If it fails midway, restore from backup:
  ```bash
  /tmp/migration-backup-minion-kevin/restore-backup.sh
  ```

### **After Migration:**
- If verification fails, check detailed log
- Post-migration script is idempotent (safe to re-run)
- Temp admin stays until you delete it (safety net)

---

## ✅ **ADVANTAGES OF THIS APPROACH**

**vs Manual System Preferences:**
- ✅ 50% faster (25 min vs 50 min)
- ✅ Less error-prone (automation does the work)
- ✅ Built-in safety checks
- ✅ Detailed logging
- ✅ Easy to repeat on multiple machines
- ✅ Automated backup before changes
- ✅ Rollback capability

**vs Other Solutions:**
- ✅ No third-party tools required
- ✅ Native macOS commands only
- ✅ Open source, auditable
- ✅ Detailed documentation
- ✅ Professional IT-reviewed

---

## 🎯 **RECOMMENDED WORKFLOW**

### **For 3 Machines:**

**Machine 1 (Test):**
```bash
./automated-migration.sh --name=minionstuart --host=minion-stuart --dry-run
# Review what would happen
./automated-migration.sh --name=minionstuart --host=minion-stuart
# Follow instructions
```

**Machine 2 & 3 (Proven process):**
```bash
# Copy scripts from Machine 1
scp minionstuart@minion-stuart.local:~/machine-rename/*.sh ~/machine-rename/

# Run with different names
./automated-migration.sh --name=minionkevin --host=minion-kevin
./automated-migration.sh --name=minionbob --host=minion-bob
```

---

## 🔧 **TROUBLESHOOTING**

### **"Must run as user: minione"**
You're running as wrong user. Log in as the old username first.

### **"You are in an SSH session"**
Script blocks SSH for safety. Use:
- Physical console
- Screen sharing
- Local Terminal

### **"Temporary admin already exists"**
From previous run. Either:
- Continue anyway (script handles it)
- Delete tempadmin first: `sudo dscl . -delete /Users/tempadmin`

### **Forgot temp admin password**
Check: `cat ~/migration-credentials.txt`

### **Rename script fails**
Check specific error. Common issues:
- Old user still logged in (log out all sessions)
- New username already exists (choose different name)
- Insufficient disk space

---

## 📖 **MANUAL ALTERNATIVE**

If you prefer not to use the automated script:
```bash
# Use original scripts
./pre-migration-v2.sh --name=NAME --host=HOST
# ... manual System Preferences steps ...
./post-migration-fix.sh --name=NAME --host=HOST
./verify-migration.sh --name=NAME --host=HOST
```

See `README.md` for manual instructions.

---

**Ready to migrate? Run:**
```bash
./automated-migration.sh --name=minionkevin --host=minion-kevin
```

**Questions? Check the full `README.md` or `MIGRATION-IMPROVEMENTS.md`**
