# Obsidian Internal Link Syntax Reference

This document provides comprehensive information about Obsidian's internal link syntax and resolution behavior.

## Basic Link Syntax

### Simple Wiki-Style Links

The most basic form of an Obsidian link:

```markdown
[[note-name]]
```

This creates a link to a note. Obsidian searches the entire vault for a matching file, regardless of folder structure.

### Links with Aliases (Display Text)

To show different text than the link target:

```markdown
[[link-target|Display Text]]
```

**Examples from the vault:**
- `[[digital-garden|Digital Garden]]` - Links to a note with id "digital-garden" but displays "Digital Garden"
- `[[second-brain|Second Brain]]` - Links to "second-brain" but displays "Second Brain"
- `[[zettelkasten-method|Zettelkasten method]]` - Custom display text

### Links to Headings

To link to a specific heading within a note:

```markdown
[[note-name#Heading Name]]
```

Can also use with aliases:

```markdown
[[note-name#Heading Name|Custom Text]]
```

### Block References

To link to a specific block with a unique identifier:

```markdown
[[note-name#^block-id]]
```

Block IDs are alphanumeric identifiers that can be added to any block in Obsidian.

### Embedded Files

To embed an image or other file:

```markdown
![[filename.ext]]
```

**Examples from the vault:**
- `![[Screenshot 2024-10-10 at 10.31.43.png]]`
- `![[Screenshot 2025-04-07 at 18.04.30.png]]`

The `!` prefix tells Obsidian to embed the content rather than just link to it.

## Link Resolution Behavior

### Search Strategy

When Obsidian encounters `[[link-name]]`, it searches for:

1. **Frontmatter ID match**: Files with `id: link-name` in their YAML frontmatter
2. **Filename match**: Files named `link-name.md` (without the extension)
3. **Alias match**: Files with `link-name` in their `aliases:` array

### Frontmatter-Based Resolution

Obsidian links can target the `id` field in a note's frontmatter:

```yaml
---
id: unique-identifier
aliases:
  - Alternative Name
  - Another Alias
tags:
  - tag1
---
```

A link `[[unique-identifier]]` will resolve to this note, even if the filename is different.

### Path Disambiguation

When multiple files have the same name in different folders:

```markdown
[[folder/subfolder/note|Display Text]]
```

This helps disambiguate when there are naming conflicts. However, Obsidian's default behavior is folder-agnostic—it searches the entire vault.

**Resolution priority when there are conflicts:**
- Obsidian may prefer files at the root level over nested files
- Using full paths in links helps avoid ambiguity
- The exact behavior can vary based on Obsidian's internal ranking

### Vault-Wide Search

By default, Obsidian searches the entire vault for link targets, regardless of the current file's location. This means:

- Links don't need to specify paths for files in different folders
- `[[note]]` works even if `note.md` is in a completely different folder
- This is different from relative path linking in other systems

## Special Cases and Edge Cases

### Links with Spaces

Both the link target and display text can contain spaces:

```markdown
[[My Note Name|My Display Text]]
```

### Case Sensitivity

- File matching is typically case-insensitive on macOS and Windows
- Case-sensitive on Linux systems
- Best practice: keep link case consistent with actual file/ID names

### Unresolved Links

If Obsidian can't find a target for a link:
- The link appears in a different color (typically purple or red, depending on theme)
- Clicking the link offers to create a new note with that name
- These are called "unresolved links" or "broken links"

### Escaped Characters

To display literal brackets without creating a link:

```markdown
\[\[not a link\]\]
```

## Vault-Specific Patterns

### Observed Naming Conventions

Based on analysis of `/Users/tolga/src/tolgaio/brain`:

1. **Kebab-case IDs**: Most common pattern
   - Example: `id: digital-garden`, `id: second-brain`

2. **Date-based IDs**: For daily notes
   - Example: `id: "2024-07-24"`

3. **IDs with spaces**: Less common but valid
   - Example: `id: Airbyte PG DB Max connected clients`

### Common Link Patterns in the Vault

Most links in the vault use the alias format:
```markdown
[[id|Display Name]]
```

This allows:
- Clean, machine-readable IDs in frontmatter
- Human-readable display text in the content
- Flexibility to change display text without breaking links

### Folder Structure Considerations

The vault has deep nesting (up to 10 levels):
- `0_inbox/` - Temporary/unsorted notes
- `1_Projects/` - Project notes
- `2_Resources/` - Reference materials
- `AI/`, `Business Ideas/`, `Journal/`, etc.

Despite this structure, links work across all folders without needing paths, thanks to Obsidian's vault-wide search.

## Best Practices for Link Creation

1. **Use frontmatter IDs**: More stable than filename-based links
2. **Provide aliases**: Make links readable in context
3. **Keep IDs unique**: Avoid naming conflicts across the vault
4. **Use paths for disambiguation**: When necessary to resolve conflicts
5. **Prefer simple links**: Let Obsidian's search find the target
6. **Be consistent**: Follow the vault's established naming patterns

## Regular Expression for Link Extraction

To extract links programmatically:

```regex
!?\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|([^\]]+))?\]\]
```

This pattern matches:
- `[[link]]` - Simple links
- `[[link|alias]]` - Links with aliases
- `[[link#heading]]` - Links to headings
- `[[link#heading|alias]]` - Heading links with aliases
- `![[file]]` - Embedded files (marked with `!` prefix)

Capture groups:
1. Link target (before `|` or `#`)
2. Display text (after `|`)

## References

- Official Obsidian documentation: https://help.obsidian.md/links
- Vault location: `/Users/tolga/src/tolgaio/brain`
