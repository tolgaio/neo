# PDF Page Size Reference

Quick reference for common page sizes supported by the PDF export skill.

## Standard Paper Sizes

### ISO A Series (International)

| Size | Dimensions (mm) | Dimensions (in) | Use Case |
|------|-----------------|-----------------|----------|
| A4 | 210 × 297 | 8.27 × 11.69 | Default, standard documents |
| A5 | 148 × 210 | 5.83 × 8.27 | Booklets, notebooks |
| A3 | 297 × 420 | 11.69 × 16.54 | Posters, large documents |

### North American Sizes

| Size | Dimensions (in) | Dimensions (mm) | Use Case |
|------|-----------------|-----------------|----------|
| Letter | 8.5 × 11 | 216 × 279 | US standard |
| Legal | 8.5 × 14 | 216 × 356 | Legal documents |
| Tabloid | 11 × 17 | 279 × 432 | Large format |
| Half Letter | 5.5 × 8.5 | 140 × 216 | Booklets |

### Book Sizes

| Name | Dimensions (in) | Use Case |
|------|-----------------|----------|
| Trade Paperback | 6 × 9 | Standard book format |
| Mass Market | 4.25 × 6.87 | Pocket paperbacks |
| Digest | 5.5 × 8.5 | Magazines, manuals |
| Royal | 6.14 × 9.21 | Premium paperback |
| Crown Quarto | 7.44 × 9.69 | Academic books |

## Using Custom Sizes

Specify custom dimensions with the `--page-size WxH` format:

```bash
# 6" × 9" trade paperback
export.sh --page-size 6x9 manuscript.md

# 5.5" × 8.5" digest
export.sh --page-size 5.5x8.5 guide.md

# Square format (8" × 8")
export.sh --page-size 8x8 portfolio.md
```

## Margin Recommendations

| Document Type | Recommended Margin |
|---------------|-------------------|
| Standard document | 1in |
| Book (reading) | 0.75in - 1in |
| Dense reference | 0.5in |
| Presentation handout | 0.75in |
| Notes with annotations | 1.5in |

```bash
# Narrow margins for dense content
export.sh --margin 0.5in reference.md

# Wide margins for annotation space
export.sh --margin 1.5in study-guide.md
```

## Common Combinations

### For Reading/Sharing
```bash
export.sh --page-size a4 --margin 1in notes.md
```

### For Printing a Book
```bash
export.sh --page-size 6x9 --margin 0.75in --title "My Book" manuscript.md
```

### For US Letter with Room for Notes
```bash
export.sh --page-size letter --margin 1.25in study-material.md
```

### For Compact Reference Card
```bash
export.sh --page-size 5.5x8.5 --margin 0.5in --no-toc cheatsheet.md
```
