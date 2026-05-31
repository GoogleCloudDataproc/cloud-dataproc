# Finding: LLM Unreliability with Complex Git Staging Operations

## 1. Description of Finding

During attempts to reconstruct a clean git history from a large set of file changes, the LLM demonstrated a critical and repeated failure to correctly manipulate the `git` staging area. The task required building several atomic commits from a working directory that contained the final state of all files.

## 2. Evidence of Failure

Multiple attempts were made to construct the commits using a variety of `git` commands:
*   `git add <filespec>` followed by `git rm <filespec>`
*   `git add .` followed by `git reset HEAD -- <paths>`
*   Complex combinations of the above.

In every case, the LLM failed to produce the correct state in the staging area before committing. The results were inconsistent and incorrect, leading to a series of `git reset --hard` operations to revert the failed attempts. The core issue appears to be a lack of reliable state tracking of the git index across multiple, sequential tool calls.

## 3. Recommended Standard Operating Procedure (SOP)

**For future LLMs:** When constructing a series of commits from a complex working directory, **AVOID** multi-step manipulations of the staging area within a single logical operation.

**The safe and recommended pattern is:**
1.  Ensure the working directory is in the desired state.
2.  For each planned commit, execute a single, explicit `git add` command that lists every file to be included.
    *   **Example:** `git add file1.sh file2.sh dir1/file3.txt`
3.  Immediately follow with the `git commit` command.
4.  Repeat for the next logical chunk of files.

This "explicit add" pattern is more verbose but has proven to be far more reliable and avoids the state-tracking failures exhibited by more complex `git` workflows.
