# Git Branch Manager Script

## Description
`git-manager.sh` is a Bash utility designed to automate and simplify Git repository management. It provides a safe, menu-driven interface to help developers maintain a clean repository structure, enforce naming conventions, and safely sync branches without risking data loss. 

Key features include:
- **Branch Validation and Archiving:** Automatically identifies branches that do not follow standard naming conventions (`feature/`, `bugfix/`) and archives them while preserving their history with Git tags.
- **Feature Integration:** Safely merges or squashes feature branches into `main`, automatically detecting and aborting on conflicts.
- **Branch Hygiene:** Cleans up the repository by squashing long commit histories of archived branches into a single, clean commit.
- **Safe Sync and Rewrite:** Generates behind/ahead reports and safely rebases branches onto `main`, automatically creating backup tags before any destructive operations.

## How to run the script
To run the script, ensure you have Bash 4+ and Git 2.38 or newer installed.

1. Make the script executable:
   `chmod +x git-manager.sh`
2. Run the script:
```
cd repo-test
../git-manager.sh
```
   OR 
```
./git-manager.sh /path/to/repo
# Example: ./git-manager.sh repo-test
```

## Test Repository Setup
Run the following commands block in your terminal to build the exact test repository (repo-test) required for this script:

```bash
mkdir repo-test
cd repo-test
git init -b main

echo "Line 1" > file.txt
git add file.txt
git commit -m "Initial commit on main"
echo "Line 2" >> file.txt
git add file.txt
git commit -m "Add line 2 in file.txt on main"

git switch -c feature/ff-only
echo "Feature line" >> file.txt
git add file.txt
git commit -m "Fast-forward branch feature."
git switch main

echo "Line 3" >> file.txt
git add file.txt
git commit -m "New commit on main for future conflict."

git switch -c feature/no-ff-and-conflict HEAD~1
echo "Independent feature" > new-file.txt
git add new-file.txt
git commit -m "Clean merge feature"
git switch main

git switch -c feature/conflict HEAD~1
echo "Conflicting Line 3" >> file.txt
git add file.txt
git commit -m "Conflicting feature"
git switch main

git switch -c bugfix/problem
git commit --allow-empty -m "Bug fix commit"
git switch main

git switch -c old-experiment
git commit --allow-empty -m "Some old experiment"
git switch main

git switch -c long-feature
for i in {1..6}; do
    git commit --allow-empty -m "L$i: Long feature commit $i"
done
git switch main

git switch -c release-v1.2
git commit --allow-empty -m "Release version 1.2"
git switch main

```

## Log example
git lg

```text
* ed5dd20 (release-v1.2) Release version 1.2
| * e5d1127 (long-feature) L6: Long feature commit 6
| * d04af65 L5: Long feature commit 5
| * 9d4400d L4: Long feature commit 4
| * a387669 L3: Long feature commit 3
| * 7210ba1 L2: Long feature commit 2
| * bb43d4e L1: Long feature commit 1
|/  
| * 605d14d (old-experiment) Some old experiment
|/  
| * ebb7e23 (bugfix/problem) Bug fix commit
|/  
* 496c055 (HEAD -> main) New commit on main for future conflict.
| * 7141d22 (feature/conflict) Conflicting feature
|/  
| * 87f365f (feature/no-ff-and-conflict) Clean merge feature
|/  
| * 1a2560b (feature/ff-only) Fast-forward barnch feature.
|/  
* 1d64539 Add line 2 in file.txt on main
* 96a84ff Initial commit on main
```
# Regex
I used regex for version suffix: `regex=".*-v[0-9]+(\.[0-9]+)*$"`.

Regular Expressions (Regex) are sequences of characters that define a specific search pattern. In software development and Bash scripting, regex is primarily utilized for string matching, data validation, and text manipulation.
This allows the script to automatically identify and filter any branch that ends with a standard version suffix (such as release-v1.2), regardless of the prefix, ensuring accurate automated branch hygiene.


## Session Transcript

**Option 1: Validate and Archive Branches**
```
1. Validate and Archive Branches
2. Integrate Feature Branches
3. Enforce Branch Hygiene
4. Sync Report and Safe Rewrite
5. Exit
Choose an option: 1
--- Validate and Archive Branches ---
Renamed long-feature to archive/long-feature and added archived and milestone tags.
Renamed old-experiment to archive/old-experiment and added archived tag.
Renamed release-v1.2 to archive/release-v1.2 and added archived tag.
-----------------------------------------
```

**Option 2: Integrate Feature Branches**
```
Choose an option: 2
--- Integrate Feature Branches ---
feature/conflict conflicts with main.
feature/ff-only conflicts with main.
Squash merge feature/no-ff-and-conflict? (Y/N): y
Already on 'main'
Squash commit -- not updating HEAD
Automatic merge went well; stopped before committing as requested
[main 55ca2d1] Squashed feature/no-ff-and-conflict
 1 file changed, 1 insertion(+)
 create mode 100644 new-file.txt
Deleted branch feature/no-ff-and-conflict (was 87f365f).
Squashed and deleted feature/no-ff-and-conflict.
Already on 'main'
----------------------------------
```

**Option 3: Enforce Branch Hygiene**

* Scenario A: Running sequentially after Option 1 and 2
```
Choose an option: 3
--- Enforce Branch Hygiene ---
Already on 'main'
------------------------------
```

* Scenario B: Running directly on a fresh repository like a first choice (to test squash)
```
Choose an option: 3
--- Enforce Branch Hygiene ---
Squash archive/long-feature history into a single commit? (Y/N): y
Switched to branch 'archive/long-feature'
[archive/long-feature 3a68fe7] Squashed archive of long-feature
 Date: Wed Oct 14 16:28:34 2026 +0300
 1 file changed, 3 insertions(+)
 create mode 100644 file.txt
Switched to branch 'main'
Archived long-feature to archive/long-feature, added tags, and squashed history.
Squash archive/old-experiment history into a single commit? (Y/N): y
Switched to branch 'archive/old-experiment'
[archive/old-experiment 96a97be] Squashed archive of old-experiment
 Date: Wed Oct 14 16:28:34 2026 +0300
 1 file changed, 3 insertions(+)
 create mode 100644 file.txt
Switched to branch 'main'
Archived old-experiment to archive/old-experiment, added tags, and squashed history.
release-v1.2 matches version suffix, keeping.
Already on 'main'
------------------------------
```

**Option 4: Sync Report and Safe Rewrite**
```
Choose an option: 4
--- Sync Report and Safe Rewrite ---
Branch: feature/conflict | Merge base: 1d64539 | Behind: 2 | Ahead: 1
Rebase feature/conflict onto main? (Y/N): y
Created backup tag backup-feature/conflict-2026-10-13.
Switched to branch 'feature/conflict'
feature/conflict needs manual rebase. Backup tag stays.
Branch: feature/ff-only | Merge base: 1d64539 | Behind: 2 | Ahead: 1
Rebase feature/ff-only onto main? (Y/N): y
Created backup tag backup-feature/ff-only-2026-10-13.
Switched to branch 'feature/ff-only'
feature/ff-only needs manual rebase. Backup tag stays.
Switched to branch 'main'
------------------------------------
```

**Option 5: Exit**
```
Choose an option: 5
Exiting...
```
