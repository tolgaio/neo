#!/usr/bin/env python3
"""
Merge Multiple Obsidian Notes for Batch PDF Export

This script is an alternative to using preprocess.py --batch directly.
It provides more control over merging behavior and ordering.
"""

import re
import sys
import yaml
import argparse
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Tuple, Optional


def extract_frontmatter(content: str) -> Tuple[dict, str]:
    """Extract YAML frontmatter and body from markdown content."""
    if not content.startswith('---'):
        return {}, content

    parts = content.split('---', 2)
    if len(parts) < 3:
        return {}, content

    try:
        fm = yaml.safe_load(parts[1]) or {}
        return fm, parts[2].strip()
    except yaml.YAMLError:
        return {}, content


def get_note_title(frontmatter: dict, filepath: Path) -> str:
    """Get note title from frontmatter or filename."""
    if 'title' in frontmatter:
        return str(frontmatter['title'])
    if 'id' in frontmatter:
        return str(frontmatter['id']).replace('-', ' ').title()
    return filepath.stem.replace('-', ' ').title()


def generate_anchor(text: str) -> str:
    """Generate URL-safe anchor from text."""
    anchor = text.lower().strip()
    anchor = re.sub(r'[^\w\s-]', '', anchor)
    anchor = re.sub(r'[\s_]+', '-', anchor)
    anchor = re.sub(r'-+', '-', anchor)
    return anchor.strip('-')


def get_sort_key(filepath: Path, frontmatter: dict) -> tuple:
    """
    Generate a sort key for ordering notes.

    Priority:
    1. Explicit 'order' field in frontmatter
    2. Alphabetical by title
    """
    order = frontmatter.get('order', 999)
    title = get_note_title(frontmatter, filepath)
    return (order, title.lower())


def merge_notes(
    note_paths: List[Path],
    title: str = None,
    sort_notes: bool = True,
    include_metadata: bool = True
) -> str:
    """
    Merge multiple notes into a single markdown document.

    Args:
        note_paths: List of paths to markdown files
        title: Document title
        sort_notes: Whether to sort notes (by frontmatter order, then title)
        include_metadata: Whether to include note metadata badges

    Returns:
        Combined markdown document
    """
    # Collect note info
    notes = []
    for path in note_paths:
        if not path.exists():
            print(f"Warning: Note not found: {path}", file=sys.stderr)
            continue

        content = path.read_text(encoding='utf-8')
        fm, body = extract_frontmatter(content)

        notes.append({
            'path': path,
            'title': get_note_title(fm, path),
            'anchor': generate_anchor(fm.get('id', path.stem)),
            'frontmatter': fm,
            'body': body,
            'stage': fm.get('stage'),
            'sort_key': get_sort_key(path, fm)
        })

    # Sort if requested
    if sort_notes:
        notes.sort(key=lambda n: n['sort_key'])

    # Build document
    doc_title = title or f"Batch Export - {datetime.now().strftime('%Y-%m-%d')}"

    output = []

    # YAML frontmatter for Pandoc
    output.append('---')
    output.append(f'title: "{doc_title}"')
    output.append(f'date: {datetime.now().strftime("%Y-%m-%d")}')
    output.append('toc-title: "Table of Contents"')
    output.append('header-includes:')
    output.append('  - \\hypersetup{bookmarksdepth=3}')
    output.append('  - \\hypersetup{bookmarksopen=true}')
    output.append('---')
    output.append('')

    # Add each note as a section
    for i, note in enumerate(notes):
        # Page break before each note (except first)
        if i > 0:
            output.append('')
            output.append('\\newpage')
            output.append('')

        # Section header with anchor
        output.append(f'# {note["title"]} {{#{note["anchor"]}}}')
        output.append('')

        # Add metadata badge if present and requested
        if include_metadata and note['stage'] in ('seedling', 'sapling', 'evergreen'):
            stage_emoji = {'seedling': '🌱', 'sapling': '🌿', 'evergreen': '🌳'}
            output.append(f'*{stage_emoji[note["stage"]]} {note["stage"].title()}*')
            output.append('')

        # Add note body (strip any existing H1)
        body = note['body']
        body = re.sub(r'^#\s+[^\n]+\n', '', body, count=1)
        output.append(body)

    return '\n'.join(output)


def main():
    parser = argparse.ArgumentParser(
        description='Merge Obsidian notes for batch PDF export'
    )
    parser.add_argument(
        'notes',
        nargs='+',
        help='Note paths to merge'
    )
    parser.add_argument(
        '--title',
        help='Document title'
    )
    parser.add_argument(
        '--order-file',
        help='File containing note paths in order (one per line)'
    )
    parser.add_argument(
        '--no-sort',
        action='store_true',
        help='Do not sort notes (use order provided)'
    )
    parser.add_argument(
        '--no-metadata',
        action='store_true',
        help='Do not include note metadata badges'
    )
    parser.add_argument(
        '-o', '--output',
        default='-',
        help='Output path (- for stdout)'
    )

    args = parser.parse_args()

    # Get note paths
    if args.order_file:
        with open(args.order_file) as f:
            note_paths = [Path(line.strip()) for line in f if line.strip()]
    else:
        note_paths = [Path(p) for p in args.notes]

    # Validate paths
    valid_paths = []
    for path in note_paths:
        if path.exists():
            valid_paths.append(path)
        else:
            print(f"Warning: Note not found: {path}", file=sys.stderr)

    if not valid_paths:
        print("Error: No valid note paths found", file=sys.stderr)
        sys.exit(1)

    # Merge notes
    result = merge_notes(
        valid_paths,
        title=args.title,
        sort_notes=not args.no_sort,
        include_metadata=not args.no_metadata
    )

    # Output
    if args.output == '-':
        print(result)
    else:
        Path(args.output).write_text(result, encoding='utf-8')
        print(f"Merged {len(valid_paths)} notes to {args.output}", file=sys.stderr)


if __name__ == '__main__':
    main()
