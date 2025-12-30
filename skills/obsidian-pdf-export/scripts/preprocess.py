#!/usr/bin/env python3
"""
Obsidian Wikilink Preprocessor for PDF Export

Converts Obsidian markdown to Pandoc-compatible markdown:
- [[wikilinks]] -> plain text (single mode) or #anchors (batch mode)
- ![[embeds]] -> standard markdown images/removed
- Adds heading anchors for internal navigation
- Preserves external URLs
"""

import re
import sys
import yaml
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


class WikilinkPreprocessor:
    """Preprocess Obsidian markdown for PDF export."""

    # Regex for Obsidian wikilinks: [[target]], [[target|display]], [[target#heading]], ![[embed]]
    WIKILINK_PATTERN = r'(!?)\[\[([^\]|#]+)(?:#([^\]|]+))?(?:\|([^\]]+))?\]\]'

    # Image extensions to preserve as markdown images
    IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.bmp'}

    def __init__(self, vault_path: str, mode: str = 'single', included_notes: List[str] = None):
        """
        Initialize the preprocessor.

        Args:
            vault_path: Path to the Obsidian vault
            mode: 'single' for single note export, 'batch' for multiple notes
            included_notes: List of note paths included in batch export (for anchor resolution)
        """
        self.vault_path = Path(vault_path).resolve()
        self.mode = mode
        self.included_notes = set(str(Path(p).resolve()) for p in (included_notes or []))

        # Build vault index for link resolution
        self.id_to_file: Dict[str, Path] = {}
        self.filename_to_file: Dict[str, Path] = {}
        self._build_index()

    def _build_index(self):
        """Index all markdown files in the vault by ID and filename."""
        if not self.vault_path.exists():
            return

        for md_file in self.vault_path.rglob("*.md"):
            # Index by filename (without extension)
            self.filename_to_file[md_file.stem] = md_file

            # Index by frontmatter ID if present
            fm_id = self._extract_frontmatter_id(md_file)
            if fm_id:
                self.id_to_file[fm_id] = md_file

    def _extract_frontmatter_id(self, file_path: Path) -> Optional[str]:
        """Extract 'id' field from YAML frontmatter."""
        try:
            content = file_path.read_text(encoding='utf-8', errors='replace')
            if not content.startswith('---'):
                return None

            parts = content.split('---', 2)
            if len(parts) < 3:
                return None

            data = yaml.safe_load(parts[1])
            if isinstance(data, dict) and 'id' in data:
                return str(data['id'])
            return None
        except Exception:
            return None

    def _generate_anchor(self, text: str) -> str:
        """Generate a URL-safe anchor ID from text."""
        # Convert to lowercase, replace spaces with hyphens, remove special chars
        anchor = text.lower().strip()
        anchor = re.sub(r'[^\w\s-]', '', anchor)
        anchor = re.sub(r'[\s_]+', '-', anchor)
        anchor = re.sub(r'-+', '-', anchor)  # Collapse multiple hyphens
        return anchor.strip('-')

    def _resolve_link_target(self, target: str) -> Tuple[Optional[Path], str]:
        """
        Resolve a wikilink target to a file path and anchor.

        Returns:
            Tuple of (resolved_path or None, anchor_id)
        """
        clean_target = target.strip()
        anchor = self._generate_anchor(clean_target)

        # Check frontmatter ID first
        if clean_target in self.id_to_file:
            return self.id_to_file[clean_target], anchor

        # Check filename
        if clean_target in self.filename_to_file:
            return self.filename_to_file[clean_target], anchor

        # Try path-based resolution
        if '/' in clean_target:
            potential = self.vault_path / f"{clean_target}.md"
            if potential.exists():
                return potential, anchor

            # Try just the filename part
            last_part = clean_target.split('/')[-1]
            if last_part in self.filename_to_file:
                return self.filename_to_file[last_part], anchor

        return None, anchor

    def _is_included_in_batch(self, target: str) -> bool:
        """Check if a link target is included in the batch export."""
        if self.mode != 'batch':
            return False

        resolved_path, _ = self._resolve_link_target(target)
        if resolved_path:
            return str(resolved_path) in self.included_notes
        return False

    def _process_wikilink(self, match: re.Match) -> str:
        """Process a single wikilink match and return replacement text."""
        is_embed = match.group(1) == '!'
        target = match.group(2).strip()
        heading = match.group(3)  # Optional #heading
        display = match.group(4)  # Optional |display text

        # Handle embedded files
        if is_embed:
            # Check if it's an image
            ext = Path(target).suffix.lower()
            if ext in self.IMAGE_EXTENSIONS:
                # Convert to standard markdown image
                alt_text = display or Path(target).stem
                return f'![{alt_text}]({target})'
            else:
                # Non-image embeds (like other notes) - remove
                return ''

        # Determine display text
        display_text = display.strip() if display else target

        # In batch mode, check if target is included
        if self._is_included_in_batch(target):
            # Create clickable anchor link
            _, anchor = self._resolve_link_target(target)
            if heading:
                anchor = f"{anchor}-{self._generate_anchor(heading)}"
            return f'[{display_text}](#{anchor})'
        else:
            # Single mode or target not in batch - just display text
            return display_text

    def process_content(self, content: str, note_id: str = None) -> str:
        """
        Process markdown content, converting wikilinks.

        Args:
            content: The markdown content to process
            note_id: Optional ID for this note (used for anchor generation in batch mode)

        Returns:
            Processed markdown content
        """
        # Process wikilinks
        processed = re.sub(self.WIKILINK_PATTERN, self._process_wikilink, content)

        # Replace standalone --- lines with *** to avoid YAML parsing issues
        # (--- is used as horizontal rule in markdown but confuses Pandoc's YAML parser)
        processed = re.sub(r'^---$', '***', processed, flags=re.MULTILINE)

        # In batch mode, add anchors to headings for internal navigation
        if self.mode == 'batch' and note_id:
            processed = self._add_heading_anchors(processed, note_id)

        return processed

    def _add_heading_anchors(self, content: str, note_id: str) -> str:
        """Add Pandoc-compatible anchor IDs to headings."""
        note_anchor = self._generate_anchor(note_id)

        def add_anchor(match: re.Match) -> str:
            hashes = match.group(1)
            title = match.group(2).strip()
            heading_anchor = self._generate_anchor(title)
            combined_anchor = f"{note_anchor}-{heading_anchor}"
            # Pandoc anchor syntax: # Heading {#anchor-id}
            return f'{hashes} {title} {{#{combined_anchor}}}'

        return re.sub(r'^(#{1,6})\s+(.+)$', add_anchor, content, flags=re.MULTILINE)

    def extract_frontmatter_and_body(self, content: str) -> Tuple[dict, str]:
        """Extract YAML frontmatter and body from markdown content."""
        if not content.startswith('---'):
            return {}, content

        parts = content.split('---', 2)
        if len(parts) < 3:
            return {}, content

        try:
            fm = yaml.safe_load(parts[1]) or {}
            if not isinstance(fm, dict):
                # Sometimes YAML parses as string or other type
                return {}, content
            return fm, parts[2].strip()
        except yaml.YAMLError as e:
            # Log warning but continue with empty frontmatter
            print(f"Warning: YAML parse error, skipping frontmatter: {e}", file=sys.stderr)
            return {}, parts[2].strip() if len(parts) > 2 else content

    def get_note_title(self, frontmatter: dict, filepath: Path) -> str:
        """Get note title from frontmatter or filename."""
        if 'title' in frontmatter:
            return str(frontmatter['title'])
        if 'id' in frontmatter:
            return str(frontmatter['id']).replace('-', ' ').title()
        return filepath.stem.replace('-', ' ').title()


def process_single_note(note_path: str, vault_path: str, output_path: str = None) -> str:
    """
    Process a single note for PDF export.

    Args:
        note_path: Path to the markdown file
        vault_path: Path to the Obsidian vault
        output_path: Optional output path (if None, prints to stdout)

    Returns:
        Processed markdown content
    """
    note_path = Path(note_path)
    content = note_path.read_text(encoding='utf-8')

    preprocessor = WikilinkPreprocessor(vault_path, mode='single')

    # Extract frontmatter
    fm, body = preprocessor.extract_frontmatter_and_body(content)

    # Process the body
    processed_body = preprocessor.process_content(body)

    # Rebuild with frontmatter (Pandoc can use it for title, etc.)
    if fm:
        result = '---\n' + yaml.dump(fm, default_flow_style=False) + '---\n\n' + processed_body
    else:
        result = processed_body

    if output_path:
        Path(output_path).write_text(result, encoding='utf-8')

    return result


def process_batch_notes(note_paths: List[str], vault_path: str, output_path: str = None,
                        title: str = None) -> str:
    """
    Process multiple notes for batch PDF export.

    Args:
        note_paths: List of paths to markdown files
        vault_path: Path to the Obsidian vault
        output_path: Optional output path
        title: Optional document title

    Returns:
        Combined and processed markdown content
    """
    resolved_paths = [str(Path(p).resolve()) for p in note_paths]
    preprocessor = WikilinkPreprocessor(vault_path, mode='batch', included_notes=resolved_paths)

    sections = []

    for note_path in note_paths:
        path = Path(note_path)
        if not path.exists():
            print(f"Warning: Note not found: {note_path}", file=sys.stderr)
            continue

        content = path.read_text(encoding='utf-8')
        fm, body = preprocessor.extract_frontmatter_and_body(content)

        # Get note title and ID
        note_title = preprocessor.get_note_title(fm, path)
        note_id = fm.get('id', path.stem)
        note_anchor = preprocessor._generate_anchor(str(note_id))

        # Process the body
        processed_body = preprocessor.process_content(body, note_id=str(note_id))

        # Remove any existing H1 (we'll add our own)
        processed_body = re.sub(r'^#\s+[^\n]+\n', '', processed_body, count=1)

        # Build section with anchor
        section = f'# {note_title} {{#{note_anchor}}}\n\n'

        # Add growth stage badge if present
        stage = fm.get('stage')
        if stage in ('seedling', 'sapling', 'evergreen'):
            emoji = {'seedling': '🌱', 'sapling': '🌿', 'evergreen': '🌳'}[stage]
            section += f'*{emoji} {stage.title()}*\n\n'

        section += processed_body
        sections.append(section)

    # Build document with frontmatter
    doc_title = title or 'Batch Export'
    from datetime import datetime

    header = f'''---
title: "{doc_title}"
date: {datetime.now().strftime('%Y-%m-%d')}
toc-title: "Table of Contents"
---

'''

    result = header + '\n\n\\newpage\n\n'.join(sections)

    if output_path:
        Path(output_path).write_text(result, encoding='utf-8')

    return result


def main():
    """Command-line interface."""
    parser = argparse.ArgumentParser(
        description='Preprocess Obsidian markdown for PDF export'
    )
    parser.add_argument(
        'files',
        nargs='+',
        help='Markdown file(s) to process'
    )
    parser.add_argument(
        '--vault',
        default=None,
        help='Path to Obsidian vault (auto-detected if not specified)'
    )
    parser.add_argument(
        '--output', '-o',
        default=None,
        help='Output file path (default: stdout)'
    )
    parser.add_argument(
        '--batch',
        action='store_true',
        help='Batch mode: combine multiple files'
    )
    parser.add_argument(
        '--title',
        default=None,
        help='Document title for batch mode'
    )

    args = parser.parse_args()

    # Auto-detect vault path
    vault_path = args.vault
    if not vault_path:
        # Try to find vault by walking up from first file
        first_file = Path(args.files[0]).resolve()
        for parent in first_file.parents:
            if (parent / '.obsidian').exists():
                vault_path = str(parent)
                break

        if not vault_path:
            # Fallback to default
            vault_path = str(Path.home() / 'src/tolgaio/brain')

    # Process based on mode
    if args.batch or len(args.files) > 1:
        result = process_batch_notes(
            args.files,
            vault_path,
            args.output,
            args.title
        )
    else:
        result = process_single_note(
            args.files[0],
            vault_path,
            args.output
        )

    # Output to stdout if no output file specified
    if not args.output:
        print(result)


if __name__ == '__main__':
    main()
