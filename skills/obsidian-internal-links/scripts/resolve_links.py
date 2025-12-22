#!/usr/bin/env python3
"""
Obsidian Internal Link Resolver

This script resolves Obsidian internal links ([[link]]) by:
1. Parsing markdown files for [[...]] syntax
2. Searching the vault for target files by frontmatter id or filename
3. Following links recursively up to a specified depth
4. Reporting broken links
"""

import re
import os
import sys
import json
import yaml
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional


class ObsidianLinkResolver:
    def __init__(self, vault_path: str):
        """Initialize the resolver with the vault path."""
        self.vault_path = Path(vault_path).resolve()
        if not self.vault_path.exists():
            raise ValueError(f"Vault path does not exist: {vault_path}")

        # Cache for file mappings: {id/filename -> file_path}
        self.id_to_file: Dict[str, Path] = {}
        self.filename_to_file: Dict[str, Path] = {}
        self._build_file_index()

    def _build_file_index(self):
        """Build an index of all markdown files in the vault."""
        for md_file in self.vault_path.rglob("*.md"):
            # Index by filename (without extension)
            filename = md_file.stem
            self.filename_to_file[filename] = md_file

            # Index by frontmatter id if present
            frontmatter_id = self._extract_frontmatter_id(md_file)
            if frontmatter_id:
                self.id_to_file[frontmatter_id] = md_file

    def _extract_frontmatter_id(self, file_path: Path) -> Optional[str]:
        """Extract the 'id' field from YAML frontmatter."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Check if file has frontmatter
            if not content.startswith('---'):
                return None

            # Extract frontmatter block
            parts = content.split('---', 2)
            if len(parts) < 3:
                return None

            frontmatter = parts[1]
            data = yaml.safe_load(frontmatter)

            if isinstance(data, dict) and 'id' in data:
                return str(data['id'])

            return None
        except Exception:
            return None

    def _extract_links(self, content: str) -> List[Tuple[str, str, str]]:
        """
        Extract all internal links from markdown content.

        Returns list of tuples: (full_match, link_target, display_text)
        - full_match: The complete [[...]] match
        - link_target: The target (before | or #)
        - display_text: The display text (after |) or None
        """
        # Pattern matches: [[link]], [[link|alias]], [[link#heading]], [[link#heading|alias]]
        # Also matches embedded files: ![[file]]
        pattern = r'!?\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|([^\]]+))?\]\]'

        matches = []
        for match in re.finditer(pattern, content):
            full_match = match.group(0)
            link_target = match.group(1).strip()
            display_text = match.group(2).strip() if match.group(2) else link_target

            # Skip embedded files (starting with !)
            if full_match.startswith('!'):
                continue

            matches.append((full_match, link_target, display_text))

        return matches

    def _resolve_link(self, link_target: str) -> Optional[Path]:
        """
        Resolve a link target to a file path.

        Resolution order:
        1. Check if it matches a frontmatter id
        2. Check if it matches a filename
        3. Check if it's a path (folder/file)
        """
        # Remove any path separators for simple matching
        clean_target = link_target.replace('\\', '/').strip()

        # Try frontmatter id first
        if clean_target in self.id_to_file:
            return self.id_to_file[clean_target]

        # Try filename match
        if clean_target in self.filename_to_file:
            return self.filename_to_file[clean_target]

        # Try path-based matching (folder/subfolder/note)
        if '/' in clean_target:
            # Try to find file at path relative to vault root
            potential_path = self.vault_path / f"{clean_target}.md"
            if potential_path.exists():
                return potential_path

            # Try just the last component (filename)
            last_component = clean_target.split('/')[-1]
            if last_component in self.filename_to_file:
                return self.filename_to_file[last_component]

        return None

    def resolve_links_in_file(
        self,
        file_path: str,
        max_depth: int = 1,
        _current_depth: int = 0,
        _visited: Optional[Set[Path]] = None
    ) -> Dict:
        """
        Resolve all links in a file, recursively up to max_depth.

        Args:
            file_path: Path to the markdown file
            max_depth: Maximum recursion depth (0 = no recursion, 1 = one level, etc.)
            _current_depth: Internal tracking of current depth
            _visited: Internal tracking of visited files to avoid cycles

        Returns:
            Dictionary with structure:
            {
                "file": str,
                "links": [
                    {
                        "link_text": str,
                        "display_text": str,
                        "resolved": bool,
                        "target_file": str or None,
                        "content": str or None,
                        "nested_links": [...] (if depth allows)
                    }
                ],
                "broken_links": [str]
            }
        """
        if _visited is None:
            _visited = set()

        file_path = Path(file_path).resolve()

        # Check if file exists
        if not file_path.exists():
            return {
                "error": f"File not found: {file_path}",
                "file": str(file_path),
                "links": [],
                "broken_links": []
            }

        # Avoid cycles
        if file_path in _visited:
            return {
                "file": str(file_path),
                "links": [],
                "broken_links": [],
                "note": "Already visited (cycle detected)"
            }

        _visited.add(file_path)

        # Read file content
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            return {
                "error": f"Failed to read file: {e}",
                "file": str(file_path),
                "links": [],
                "broken_links": []
            }

        # Extract links
        link_matches = self._extract_links(content)

        result = {
            "file": str(file_path),
            "links": [],
            "broken_links": []
        }

        for full_match, link_target, display_text in link_matches:
            # Resolve the link
            resolved_file = self._resolve_link(link_target)

            link_info = {
                "link_text": link_target,
                "display_text": display_text,
                "resolved": resolved_file is not None
            }

            if resolved_file:
                link_info["target_file"] = str(resolved_file)

                # Read content of linked file
                try:
                    with open(resolved_file, 'r', encoding='utf-8') as f:
                        linked_content = f.read()
                        link_info["content"] = linked_content

                        # If we haven't reached max depth, recurse
                        if _current_depth < max_depth:
                            nested_result = self.resolve_links_in_file(
                                resolved_file,
                                max_depth=max_depth,
                                _current_depth=_current_depth + 1,
                                _visited=_visited.copy()
                            )
                            link_info["nested_links"] = nested_result.get("links", [])

                            # Bubble up broken links from nested files
                            result["broken_links"].extend(nested_result.get("broken_links", []))
                except Exception as e:
                    link_info["error"] = f"Failed to read linked file: {e}"
            else:
                result["broken_links"].append(link_target)
                link_info["target_file"] = None
                link_info["content"] = None

            result["links"].append(link_info)

        # Remove duplicate broken links
        result["broken_links"] = list(set(result["broken_links"]))

        return result


def main():
    """Command-line interface for the link resolver."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Resolve Obsidian internal links in a markdown file"
    )
    parser.add_argument(
        "file",
        help="Path to the markdown file to process"
    )
    parser.add_argument(
        "--vault",
        default="/Users/tolga/src/tolgaio/brain",
        help="Path to the Obsidian vault (default: /Users/tolga/src/tolgaio/brain)"
    )
    parser.add_argument(
        "--depth",
        type=int,
        default=1,
        help="Maximum recursion depth for following links (default: 1)"
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output"
    )

    args = parser.parse_args()

    try:
        resolver = ObsidianLinkResolver(args.vault)
        result = resolver.resolve_links_in_file(args.file, max_depth=args.depth)

        indent = 2 if args.pretty else None
        print(json.dumps(result, indent=indent, ensure_ascii=False))

    except Exception as e:
        print(json.dumps({"error": str(e)}, indent=2), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
