# Fabric Pattern Import

Import Fabric patterns into NEO skills.

**Usage:**

- `/fabric-import` - Import all categories
- `/fabric-import analyze` - Import only the "analyze" category
- `/fabric-import analyze,summarize` - Import multiple categories (comma-separated)
- `/fabric-import analyze summarize` - Import multiple categories (space-separated)

## Instructions

### Step 1: Clone/Update Fabric Repository

First, ensure the Fabric repository is available locally:

```bash
if [ -d /tmp/fabric-patterns ]; then
  cd /tmp/fabric-patterns && git pull
else
  git clone --depth 1 https://github.com/danielmiessler/fabric.git /tmp/fabric-patterns
fi
```

### Step 2: Determine Categories to Import

**If arguments are provided:**

- Split `$ARGUMENTS` on commas and/or spaces to get a list of categories
- Import each category in the list

**If no arguments provided:**

- List all patterns: `ls /tmp/fabric-patterns/data/patterns/`
- Extract unique category prefixes (text before first `_`)
- Example: `analyze_paper` → category `analyze`

### Step 3: Spawn Import Agents

For each category, use the Task tool to spawn a `fabric-category-importer` agent:

```
Task:
  subagent_type: fabric-category-importer
  prompt: |
    Import all patterns from the "{category}" category from Fabric into NEO skills.

    IMPORTANT: The Fabric repository is at /tmp/fabric-patterns/data/patterns/
    DO NOT use network requests. Read patterns from the local clone.

    Only import patterns that actually exist. DO NOT make up patterns.
```

**Spawn up to 5 agents in parallel per batch.**

### Step 4: Monitor and Report

After all agents complete:

1. Run the status update: `/home/tolga/src/tolgaio/neo/scripts/update-fabric-status.sh`
2. Report the final statistics from `fabric_import_status.md`
