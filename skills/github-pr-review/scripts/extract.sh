#!/bin/bash

# github_pr_to_llm.sh
# Script to convert GitHub PR changes to LLM-friendly format

set -e

# Check for required commands
for cmd in curl jq git; do
  if ! command -v $cmd &>/dev/null; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

# Function to display usage information
show_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  -o, --owner OWNER        GitHub repository owner (required)"
  echo "  -r, --repo REPO          GitHub repository name (required)"
  echo "  -p, --pr PR_NUMBER       Pull request number (required)"
  echo "  -t, --token TOKEN        GitHub personal access token (optional)"
  echo "  -d, --output-dir DIR     Output directory (default: $BRAIN_HOME/github-pr-reviews/{owner}/{repo}/pr-{number})"
  echo "  -h, --help               Show this help message"
  exit 1
}

# Default values
OUTPUT_DIR=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
  -o | --owner)
    OWNER="$2"
    shift
    ;;
  -r | --repo)
    REPO="$2"
    shift
    ;;
  -p | --pr)
    PR_NUMBER="$2"
    shift
    ;;
  -t | --token)
    TOKEN="$2"
    shift
    ;;
  -d | --output-dir)
    OUTPUT_DIR="$2"
    shift
    ;;
  -h | --help) show_usage ;;
  *)
    echo "Unknown parameter: $1"
    show_usage
    ;;
  esac
  shift
done

# If token not provided via CLI, try to use GITHUB_TOKEN environment variable
if [ -z "$TOKEN" ] && [ -n "$GITHUB_TOKEN" ]; then
  TOKEN="$GITHUB_TOKEN"
  echo "Using GITHUB_TOKEN from environment"
fi

# Check required parameters
if [ -z "$OWNER" ] || [ -z "$REPO" ] || [ -z "$PR_NUMBER" ]; then
  echo "Error: Missing required parameters."
  show_usage
fi

# Set default output directory if not provided
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$BRAIN_HOME/github-pr-reviews/${OWNER}/${REPO}/pr-${PR_NUMBER}"
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Set output file path
OUTPUT_FILE="${OUTPUT_DIR}/extract.md"

# Prepare auth header if token is provided
AUTH_HEADER=""
if [ -n "$TOKEN" ]; then
  AUTH_HEADER="-H \"Authorization: token $TOKEN\""
fi

echo "Fetching PR #$PR_NUMBER from $OWNER/$REPO..."

# Get PR details
PR_DETAILS=$(curl -s ${TOKEN:+-H "Authorization: token $TOKEN"} \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER")

# Check for GitHub API errors
if echo "$PR_DETAILS" | jq -e 'has("message")' >/dev/null 2>&1; then
  error_message=$(echo "$PR_DETAILS" | jq -r '.message')

  if [ "$error_message" = "Not Found" ]; then
    echo "Error: Pull request #$PR_NUMBER not found in $OWNER/$REPO" >&2
    echo "" >&2
    echo "Please verify:" >&2
    echo "  - The PR number is correct" >&2
    echo "  - The repository owner and name are correct" >&2
    echo "  - The PR exists and hasn't been deleted" >&2
    echo "  - You have access to view this PR (use -t/--token if it's private)" >&2
    exit 1
  else
    echo "Error: GitHub API returned an error: $error_message" >&2
    echo "Full response: $PR_DETAILS" >&2
    exit 1
  fi
fi

# Verify we got valid PR data
if ! echo "$PR_DETAILS" | jq -e '.title' >/dev/null 2>&1; then
  echo "Error: Invalid response from GitHub API" >&2
  echo "Response: $PR_DETAILS" >&2
  exit 1
fi

PR_TITLE=$(echo "$PR_DETAILS" | jq -r .title)
PR_BODY=$(echo "$PR_DETAILS" | jq -r .body)
PR_AUTHOR=$(echo "$PR_DETAILS" | jq -r .user.login)
PR_URL=$(echo "$PR_DETAILS" | jq -r .html_url)

# Get PR files
PR_FILES=$(curl -s ${TOKEN:+-H "Authorization: token $TOKEN"} \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/files")

# Get PR comments (general comments on the PR)
PR_COMMENTS=$(curl -s ${TOKEN:+-H "Authorization: token $TOKEN"} \
  "https://api.github.com/repos/$OWNER/$REPO/issues/$PR_NUMBER/comments")

# Get PR review comments (line-specific comments)
PR_REVIEW_COMMENTS=$(curl -s ${TOKEN:+-H "Authorization: token $TOKEN"} \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments")

# Get commits
PR_COMMITS=$(curl -s ${TOKEN:+-H "Authorization: token $TOKEN"} \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/commits")

# Get reviews (for threaded discussions and approval state)
PR_REVIEWS=$(curl -s ${TOKEN:+-H "Authorization: token $TOKEN"} \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews")

# Create output file with PR details
cat >"$OUTPUT_FILE" <<EOF
# GitHub Pull Request Analysis

## Metadata
- **Repository:** $OWNER/$REPO
- **PR Number:** #$PR_NUMBER
- **Title:** $PR_TITLE
- **Author:** $PR_AUTHOR
- **URL:** $PR_URL
- **Analysis Date:** $(date '+%Y-%m-%d %H:%M:%S')

## Pull Request Description
$PR_BODY

## Commit History
EOF

# Add commits
if [ "$(echo "$PR_COMMITS" | jq '. | length')" -gt 0 ]; then
  echo "$PR_COMMITS" | jq -c '.[]' | while read -r commit; do
    commit_sha=$(echo "$commit" | jq -r '.sha[:7]')
    commit_author=$(echo "$commit" | jq -r '.commit.author.name')
    commit_date=$(echo "$commit" | jq -r '.commit.author.date')
    commit_message=$(echo "$commit" | jq -r '.commit.message')
    commit_title=$(echo "$commit_message" | head -1)
    commit_body=$(echo "$commit_message" | tail -n +3)

    echo "" >>"$OUTPUT_FILE"
    echo "### \`$commit_sha\` - $commit_title" >>"$OUTPUT_FILE"
    echo "**Author:** $commit_author | **Date:** $(date -d "$commit_date" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$commit_date")" >>"$OUTPUT_FILE"
    if [ -n "$commit_body" ] && [ "$commit_body" != "$commit_title" ]; then
      echo "" >>"$OUTPUT_FILE"
      echo "$commit_body" >>"$OUTPUT_FILE"
    fi
  done
else
  echo "No commits found." >>"$OUTPUT_FILE"
fi

cat >>"$OUTPUT_FILE" <<EOF

## Summary of Changes
This pull request modifies $(echo "$PR_FILES" | jq '. | length') file(s).

## Comments and Discussion

### General PR Comments
EOF

# Add general PR comments
if [ "$(echo "$PR_COMMENTS" | jq '. | length')" -gt 0 ]; then
  echo "$PR_COMMENTS" | jq -c '.[]' | while read -r comment; do
    comment_author=$(echo "$comment" | jq -r .user.login)
    comment_body=$(echo "$comment" | jq -r .body)
    comment_date=$(echo "$comment" | jq -r .created_at)

    cat >>"$OUTPUT_FILE" <<EOF

**@$comment_author** ($(date -d "$comment_date" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$comment_date")):
$comment_body

---
EOF
  done
else
  echo "No general comments on this PR." >>"$OUTPUT_FILE"
fi

cat >>"$OUTPUT_FILE" <<EOF

### Code Review Comments
EOF

# Add code review comments
if [ "$(echo "$PR_REVIEW_COMMENTS" | jq '. | length')" -gt 0 ]; then
  echo "$PR_REVIEW_COMMENTS" | jq -c '.[]' | while read -r comment; do
    comment_author=$(echo "$comment" | jq -r .user.login)
    comment_body=$(echo "$comment" | jq -r .body)
    comment_file=$(echo "$comment" | jq -r .path)
    comment_line=$(echo "$comment" | jq -r .line)
    comment_date=$(echo "$comment" | jq -r .created_at)

    cat >>"$OUTPUT_FILE" <<EOF

**@$comment_author** commented on \`$comment_file:$comment_line\` ($(date -d "$comment_date" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$comment_date")):
$comment_body

---
EOF
  done
else
  echo "No code review comments on this PR." >>"$OUTPUT_FILE"
fi

cat >>"$OUTPUT_FILE" <<EOF

### Reviews
EOF

# Add reviews with state
if [ "$(echo "$PR_REVIEWS" | jq '. | length')" -gt 0 ]; then
  echo "$PR_REVIEWS" | jq -c '.[]' | while read -r review; do
    review_author=$(echo "$review" | jq -r '.user.login')
    review_state=$(echo "$review" | jq -r '.state')
    review_body=$(echo "$review" | jq -r '.body // ""')
    review_date=$(echo "$review" | jq -r '.submitted_at')

    case "$review_state" in
    APPROVED) state_icon="[APPROVED]" ;;
    CHANGES_REQUESTED) state_icon="[CHANGES REQUESTED]" ;;
    COMMENTED) state_icon="[COMMENTED]" ;;
    DISMISSED) state_icon="[DISMISSED]" ;;
    *) state_icon="[$review_state]" ;;
    esac

    echo "" >>"$OUTPUT_FILE"
    echo "**@$review_author** $state_icon ($(date -d "$review_date" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$review_date"))" >>"$OUTPUT_FILE"
    if [ -n "$review_body" ] && [ "$review_body" != "null" ]; then
      echo "" >>"$OUTPUT_FILE"
      echo "$review_body" >>"$OUTPUT_FILE"
    fi
    echo "" >>"$OUTPUT_FILE"
    echo "---" >>"$OUTPUT_FILE"
  done
else
  echo "No reviews on this PR." >>"$OUTPUT_FILE"
fi

cat >>"$OUTPUT_FILE" <<EOF

## File-by-File Analysis
EOF

# Process each file in the PR
echo "$PR_FILES" | jq -c '.[]' | while read -r file; do
  filename=$(echo "$file" | jq -r .filename)
  status=$(echo "$file" | jq -r .status)
  additions=$(echo "$file" | jq -r .additions)
  deletions=$(echo "$file" | jq -r .deletions)
  changes=$(echo "$file" | jq -r .changes)
  patch=$(echo "$file" | jq -r '.patch // "No patch available"')

  # Add file info to the output
  cat >>"$OUTPUT_FILE" <<EOF

### 📁 $filename

**Change Summary:**
- **Status:** $status
- **Lines Added:** $additions
- **Lines Deleted:** $deletions
- **Total Changes:** $changes lines

**Diff:**
\`\`\`diff
$patch
\`\`\`
EOF

  # For added or modified files, fetch the complete new content
  if [ "$status" != "removed" ]; then
    # Get the raw content URL
    content_url=$(curl -s ${TOKEN:+-H "Authorization: token $TOKEN"} \
      "https://api.github.com/repos/$OWNER/$REPO/contents/$filename?ref=$(echo "$PR_DETAILS" | jq -r .head.ref)" |
      jq -r '.download_url // empty')

    if [ -n "$content_url" ]; then
      # Get file extension for syntax highlighting
      extension="${filename##*.}"

      # Add the file header with proper syntax highlighting
      if [ "$extension" != "$filename" ]; then
        echo "**Full File Content (Post-Change):**" >>"$OUTPUT_FILE"
        echo '```'"$extension" >>"$OUTPUT_FILE"
      else
        echo "**Full File Content (Post-Change):**" >>"$OUTPUT_FILE"
        echo '```' >>"$OUTPUT_FILE"
      fi

      # Fetch and append content
      curl -s "$content_url" >>"$OUTPUT_FILE"
      echo "" >>"$OUTPUT_FILE"
      echo '```' >>"$OUTPUT_FILE"
    fi
  fi
done

echo -e "\n## Analysis Framework\n" >>"$OUTPUT_FILE"
echo "Please analyze this pull request focusing on the following areas:" >>"$OUTPUT_FILE"
echo "" >>"$OUTPUT_FILE"
echo "### 🔍 **Code Quality Review**" >>"$OUTPUT_FILE"
echo "- Logic errors or bugs" >>"$OUTPUT_FILE"
echo "- Code structure and organization" >>"$OUTPUT_FILE"
echo "- Performance implications" >>"$OUTPUT_FILE"
echo "- Adherence to best practices" >>"$OUTPUT_FILE"
echo "" >>"$OUTPUT_FILE"
echo "### 🔒 **Security Analysis**" >>"$OUTPUT_FILE"
echo "- Potential security vulnerabilities" >>"$OUTPUT_FILE"
echo "- Input validation and sanitization" >>"$OUTPUT_FILE"
echo "- Authentication and authorization" >>"$OUTPUT_FILE"
echo "" >>"$OUTPUT_FILE"
echo "### 🧪 **Testing & Documentation**" >>"$OUTPUT_FILE"
echo "- Test coverage adequacy" >>"$OUTPUT_FILE"
echo "- Documentation completeness" >>"$OUTPUT_FILE"
echo "- Edge case handling" >>"$OUTPUT_FILE"
echo "" >>"$OUTPUT_FILE"
echo "### 💡 **Suggestions**" >>"$OUTPUT_FILE"
echo "- Code improvements or optimizations" >>"$OUTPUT_FILE"
echo "- Alternative approaches" >>"$OUTPUT_FILE"
echo "- Maintainability enhancements" >>"$OUTPUT_FILE"

# Generate documentation links based on file types
echo -e "\n## Relevant Documentation\n" >>"$OUTPUT_FILE"
echo "Based on file types in this PR, the following documentation may be helpful:" >>"$OUTPUT_FILE"
echo "" >>"$OUTPUT_FILE"

# Collect unique extensions and patterns
declare -A doc_links
while read -r filename; do
  ext="${filename##*.}"
  case "$ext" in
  tf | hcl)
    doc_links["Terraform"]="https://registry.terraform.io/providers/"
    ;;
  go)
    doc_links["Go"]="https://pkg.go.dev/"
    ;;
  py)
    doc_links["Python"]="https://docs.python.org/3/"
    ;;
  ts | tsx)
    doc_links["TypeScript"]="https://www.typescriptlang.org/docs/"
    ;;
  js | jsx)
    doc_links["JavaScript/MDN"]="https://developer.mozilla.org/en-US/docs/Web/JavaScript"
    ;;
  rs)
    doc_links["Rust"]="https://doc.rust-lang.org/"
    ;;
  java)
    doc_links["Java"]="https://docs.oracle.com/en/java/"
    ;;
  rb)
    doc_links["Ruby"]="https://ruby-doc.org/"
    ;;
  sh | bash)
    doc_links["Bash"]="https://www.gnu.org/software/bash/manual/"
    ;;
  esac
  # Check for specific filenames
  case "$filename" in
  *Dockerfile* | *dockerfile*)
    doc_links["Docker"]="https://docs.docker.com/reference/"
    ;;
  *docker-compose*)
    doc_links["Docker Compose"]="https://docs.docker.com/compose/"
    ;;
  *.yaml | *.yml)
    if echo "$filename" | grep -qiE '(k8s|kubernetes|deploy|service|ingress|configmap|secret)'; then
      doc_links["Kubernetes"]="https://kubernetes.io/docs/"
    fi
    ;;
  *github/workflows*)
    doc_links["GitHub Actions"]="https://docs.github.com/en/actions"
    ;;
  *Makefile* | *makefile*)
    doc_links["Make"]="https://www.gnu.org/software/make/manual/"
    ;;
  esac
done < <(echo "$PR_FILES" | jq -r '.[].filename')

# Output documentation links
if [ ${#doc_links[@]} -gt 0 ]; then
  for tech in "${!doc_links[@]}"; do
    echo "- **$tech**: ${doc_links[$tech]}" >>"$OUTPUT_FILE"
  done
else
  echo "No specific documentation links identified for the file types in this PR." >>"$OUTPUT_FILE"
fi

# Output success message with directory path for review file
echo "PR changes successfully extracted to $OUTPUT_FILE"
echo "Review directory: $OUTPUT_DIR"
echo "Save your review to: ${OUTPUT_DIR}/review.md"
