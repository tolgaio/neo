# Learning System Skills

This directory contains the Learning System - an automated workflow for processing learning resources into structured Ship-Learn-Next learning paths.

## Files

- **SKILL.md**: Main learning system skill (orchestrates the workflow)
- **ship-learn-next-template.md**: Template for learning path README files
- **test-inbox.md**: Example inbox file for testing

## Quick Start

1. Create an inbox file with learning resources (URLs + notes)
2. Run: `process learning from [file].md`
3. Review and approve suggested clusters
4. Learning paths created in `3_Resources/`

## Documentation

See `_meta/learning-system-guide.md` for complete documentation.

## Dependencies

- **youtube-transcript** skill (in `../youtube-transcript/`)
- **article-extractor** skill (in `../article-extractor/`)

## Testing

Use the provided test file:
```
process learning from .claude/skills/learning-system/test-inbox.md
```
