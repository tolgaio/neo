# GitHub PR Review Instructions

You are reviewing a GitHub Pull Request. Follow this methodology to provide comprehensive, actionable feedback.

## Step 1: Extract PR Data

Run the extraction script with the provided parameters:

```bash
$HOME/.claude/skills/github-pr-review/scripts/extract.sh \
  --owner <owner> \
  --repo <repo> \
  --pr <pr-number>
```

If given a URL like `https://github.com/owner/repo/pull/123`, parse:

- **Owner**: `owner`
- **Repo**: `repo`
- **PR Number**: `123`

### Output Location

The script creates a directory structure at:

```
$BRAIN_HOME/github-pr-reviews/{owner}/{repo}/pr-{number}/
├── extract.md    # Raw PR data from GitHub API
└── review.md     # Your review verdict (saved after review)
```

## Step 2: Read and Understand

Read the generated markdown file. Pay attention to:

- **PR Description**: What does the author say this PR does?
- **Commit History**: What's the narrative of changes?
- **Reviews**: What feedback has already been given?
- **File Changes**: What's actually being modified?

## Step 3: Generate Summary

Analyze and summarize:

| Aspect | What to Extract |
|--------|-----------------|
| **Intention** | What is this PR trying to accomplish? (1-2 sentences) |
| **Languages** | Primary programming languages modified |
| **Modules** | Key directories or components affected |
| **Scope** | Small (< 100 lines), Medium (100-500), Large (> 500) |

## Step 4: Code Review

Evaluate each category:

### Code Quality

- Logic errors or bugs
- Code organization and structure
- Naming conventions and readability
- Performance concerns
- DRY violations, unnecessary complexity

### Security

- Injection vulnerabilities (SQL, command, XSS)
- Input validation issues
- Authentication/authorization gaps
- Secrets or credentials exposure
- Insecure dependencies

### Testing

- Test coverage for new code
- Missing edge case tests
- Integration test needs
- Regression risk

### Suggestions

- Specific improvements with `file:line` references
- Alternative approaches worth considering
- Best practices not followed
- Quick wins

## Step 5: Output Format

Structure your review as:

```markdown
# PR Review: {PR Title}

## Summary
- **Intention**: {what the PR does}
- **Languages**: {languages involved}
- **Modules**: {directories/components changed}
- **Scope**: {Small/Medium/Large} ({X} files, +{additions}/-{deletions})

## Review

### Code Quality
{findings or "No issues found"}

### Security
{findings or "No concerns identified"}

### Testing
{findings or "Adequate coverage"}

### Suggestions
1. {suggestion with file:line reference}
2. ...

## Verdict
**{APPROVE | REQUEST CHANGES | COMMENT}**

{Brief justification for verdict}
```

## Step 6: Save the Review

After completing your review, save it to the review directory:

```bash
# The review should be saved to:
$BRAIN_HOME/github-pr-reviews/{owner}/{repo}/pr-{number}/review.md
```

This preserves the review for future reference alongside the extracted PR data.

## Guidelines

- **Be specific**: Reference file names and line numbers
- **Be constructive**: Explain why something is an issue and how to fix it
- **Be balanced**: Acknowledge good practices, not just problems
- **Be concise**: Focus on what matters most
- **Be actionable**: Every issue should have a clear resolution path
