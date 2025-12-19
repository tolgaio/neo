#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FABRIC_DIR="/tmp/fabric-patterns"
PATTERNS_PATH="$FABRIC_DIR/data/patterns"
OUTPUT_FILE="$PROJECT_ROOT/fabric_import_status.md"
SKILLS_DIR="$PROJECT_ROOT/skills"

# Clone or update Fabric repo (sparse checkout for patterns only)
if [ ! -d "$FABRIC_DIR" ]; then
  echo "Cloning Fabric repository..."
  git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/danielmiessler/fabric.git "$FABRIC_DIR"
  cd "$FABRIC_DIR"
  git sparse-checkout set data/patterns
else
  echo "Updating Fabric repository..."
  cd "$FABRIC_DIR"
  git pull --quiet
fi

# Count total patterns
TOTAL_PATTERNS=$(ls -1 "$PATTERNS_PATH" | wc -l)

# Get categories and counts
declare -A FABRIC_COUNTS
while IFS= read -r pattern; do
  category="${pattern%%_*}"
  ((FABRIC_COUNTS[$category]++)) || FABRIC_COUNTS[$category]=1
done < <(ls -1 "$PATTERNS_PATH")

# Count local skills per category
declare -A LOCAL_COUNTS
if [ -d "$SKILLS_DIR" ]; then
  for category_dir in "$SKILLS_DIR"/*/; do
    if [ -d "$category_dir" ]; then
      category=$(basename "$category_dir")
      count=$(find "$category_dir" -maxdepth 2 -name "SKILL.md" | wc -l)
      if [ "$count" -gt 0 ]; then
        LOCAL_COUNTS[$category]=$count
      fi
    fi
  done
fi

TOTAL_IMPORTED=0
for count in "${LOCAL_COUNTS[@]}"; do
  ((TOTAL_IMPORTED+=count))
done

# Generate markdown report
cat > "$OUTPUT_FILE" << EOF
# Fabric Pattern Import Status

> Last updated: $(date +%Y-%m-%d)

## Overview

- **Source:** https://github.com/danielmiessler/fabric/tree/main/data/patterns
- **Total Fabric patterns:** $TOTAL_PATTERNS
- **Total imported:** $TOTAL_IMPORTED skills
- **Categories:** ${#FABRIC_COUNTS[@]}

## Import Status by Category

| Category | Total Patterns | Imported | Status |
|----------|---------------|----------|--------|
EOF

# Sort categories and output table
for category in $(echo "${!FABRIC_COUNTS[@]}" | tr ' ' '\n' | sort); do
  fabric_count=${FABRIC_COUNTS[$category]}
  local_count=${LOCAL_COUNTS[$category]:-0}

  if [ "$local_count" -eq 0 ]; then
    status=":x: Not imported"
  elif [ "$local_count" -ge "$fabric_count" ]; then
    status=":white_check_mark: Complete"
  else
    status=":warning: Partial"
  fi

  echo "| **$category** | $fabric_count | $local_count | $status |" >> "$OUTPUT_FILE"
done

# Add imported skills section
cat >> "$OUTPUT_FILE" << EOF

## Imported Skills
EOF

for category_dir in "$SKILLS_DIR"/*/; do
  if [ -d "$category_dir" ]; then
    category=$(basename "$category_dir")
    skills=$(find "$category_dir" -maxdepth 2 -name "SKILL.md" -exec dirname {} \; | xargs -I{} basename {} | sort)
    if [ -n "$skills" ]; then
      count=$(echo "$skills" | wc -l)
      echo "" >> "$OUTPUT_FILE"
      echo "### $category/ ($count skills)" >> "$OUTPUT_FILE"
      echo "$skills" | while read skill; do
        echo "- $skill" >> "$OUTPUT_FILE"
      done
    fi
  fi
done

echo ""
echo "Updated: $OUTPUT_FILE"
echo "Total patterns: $TOTAL_PATTERNS"
echo "Total imported: $TOTAL_IMPORTED"
