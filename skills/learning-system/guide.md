# Learning System Guide

## Overview

The Learning System is an automated workflow that transforms scattered learning resources (YouTube videos, articles, PDFs, and your notes) into structured Ship-Learn-Next learning paths.

## Quick Start

1. **Collect resources** in a markdown file (e.g., `AI/Inbox.md`)
   - Add URLs (YouTube, articles)
   - Write your thoughts and notes
   - Use checkboxes `- [ ]` to mark items

2. **Process the inbox**
   ```
   process learning from AI/Inbox.md
   ```

3. **Review suggested clusters**
   - AI will propose topic groupings
   - Approve, rename, split, or merge as needed

4. **Learning paths created** in `3_Resources/[topic]/`
   - README with Ship-Learn-Next plan
   - Extracted content in `sources/`
   - Your notes in `notes/`

## File Format

Your inbox file can be any markdown file with:

```markdown
# My Learning Resources

## To Process
- [ ] https://www.youtube.com/watch?v=VIDEO_ID
- [ ] https://example.com/article
- [ ] My thoughts about this topic...

## Another Section
- [ ] https://example.com/another-article
- [ ] Some more notes here
```

**Tips:**
- Use sections/headings to organize by rough topics
- Add your context - helps clustering
- Mix URLs and notes freely
- Use checkboxes for tracking

## The Ship-Learn-Next Framework

Each learning path uses this structure:

### Ship 🚢 (Build First)
Practical projects to build while learning. Learning by doing is most effective.

### Learn 📚 (Study)
Resources to read, watch, and understand. Includes all your collected sources.

### Next ➡️ (What's After)
Advanced topics and next steps after mastering this path.

## Workflow Details

### 1. Content Extraction
- **YouTube videos**: Transcripts extracted via yt-dlp
- **Web articles**: Content cleaned via Mozilla Readability
- **PDFs**: Text extracted directly
- **Your notes**: Preserved as-is

### 2. AI Clustering
- Analyzes all content together
- Identifies topic patterns
- Uses your notes as strong signals
- Suggests logical groupings

### 3. Interactive Approval
You control the final structure:
- Approve suggested clusters
- Rename topics
- Split complex topics
- Merge similar topics
- Exclude irrelevant sources

### 4. Path Creation
Creates folders in `3_Resources/`:
```
3_Resources/
└── kubernetes-networking/
    ├── README.md              # Ship-Learn-Next plan
    ├── sources/               # Extracted content
    │   ├── istio-video-transcript.md
    │   └── k8s-networking-article.md
    └── notes/                 # Your notes
        └── service-mesh-thoughts.md
```

### 5. Inbox Cleanup
Processed items moved to "Processed" section with checkmarks:
```markdown
## Processed (2025-11-22)
- [x] https://youtube.com/... → kubernetes-networking
- [x] My notes about mTLS → kubernetes-networking
```

## Living Learning Paths

Learning paths are designed to grow:

- **Adding more content**: Run the system again with new resources
- **Automatic merging**: New content merges into existing paths
- **Plan updates**: Ship-Learn-Next plans updated with new material
- **Progress tracking**: Check off items as you learn

## Status Progression

Learning paths follow your vault's maturity system:

- 🌱 **Seedling**: New path, just starting
- 🌿 **Sapling**: Actively learning, making progress
- 🌳 **Evergreen**: Well understood, reference material

Update the `status` field in README frontmatter as you progress.

## Best Practices

### Collection Phase
- ⭐ **Add context**: Write why resources interest you
- ⭐ **Group loosely**: Use headings for rough categories
- ⭐ **Collect in batches**: Process when you have 5+ items
- ⭐ **Include variety**: Mix videos, articles, and notes

### Processing Phase
- ⭐ **Review carefully**: AI suggestions are starting points
- ⭐ **Merge wisely**: Better to split and merge later than force grouping
- ⭐ **Name clearly**: Use descriptive topic names
- ⭐ **Accept failures**: Some sources won't extract (paywalls, etc.)

### Learning Phase
- ⭐ **Start with Ship**: Build projects first
- ⭐ **Update progress**: Check off completed items
- ⭐ **Refine plans**: Edit Ship-Learn-Next sections as you learn
- ⭐ **Link liberally**: Connect to other notes in your vault
- ⭐ **Update status**: Progress from seedling to evergreen

### Maintenance
- ⭐ **Weekly review**: Check new learning paths
- ⭐ **Archive completed**: Move to `4_Archives/resources/`
- ⭐ **Merge related**: Combine paths that overlap
- ⭐ **Clean sources**: Remove outdated/irrelevant content

## Integration with Your System

### PARA Structure
- **3_Resources**: Learning paths live here (reference material)
- **2_Areas**: Active learning tracked separately (if desired)
- **1_Projects**: Practical projects from "Ship" sections
- **4_Archives**: Completed learning paths

### Reviews
- **Daily**: Quick capture in inbox
- **Weekly**: Process inbox, review new paths
- **Monthly**: Update path status, check progress
- **Quarterly**: Archive completed, merge related

### Dataview Queries
Track learning with queries:

```dataview
TABLE status as Status, topics as Topics
FROM "3_Resources"
WHERE type = "learning-path"
SORT status ASC
```

## Troubleshooting

### No clusters found
- Sources too diverse - AI can't find patterns
- Solution: Create individual paths or add more context

### Extraction failed
- Paywalled, geo-blocked, or deleted content
- Solution: System saves URL for manual review

### Wrong clustering
- AI misunderstood relationships
- Solution: Split during approval phase

### Path collision
- Learning path already exists
- Solution: System automatically merges new content

### Missing transcripts
- Video doesn't have transcripts available
- Solution: URL saved with note to watch manually

## Dependencies

### Required Skills
- `youtube-transcript`: Extracts YouTube transcripts via yt-dlp
- `article-extractor`: Cleans web articles via Mozilla Readability

### External Tools
- **yt-dlp**: Install with `pip install yt-dlp`
- Readability handled by Claude's WebFetch tool (built-in)

### Configuration
- No configuration needed
- Works with default Obsidian setup
- Compatible with existing plugins (Dataview, etc.)

## Examples

### Simple Inbox
```markdown
## To Learn
- [ ] https://youtube.com/watch?v=abc
- [ ] https://example.com/article
```
Result: One learning path with 2 sources

### Clustered Inbox
```markdown
## Kubernetes
- [ ] https://youtube.com/k8s-video
- [ ] https://k8s.io/docs/...

## Rust
- [ ] https://youtube.com/rust-video
- [ ] My notes about ownership
```
Result: Two learning paths (Kubernetes, Rust)

### Mixed Inbox
```markdown
- [ ] https://youtube.com/video1
- [ ] Random thoughts
- [ ] https://article.com/post
```
Result: AI clusters based on content analysis

## Tips for Success

1. **Trust the process**: Let AI suggest clusters, refine during approval
2. **Add your voice**: Your notes improve clustering accuracy
3. **Iterate quickly**: Better to process often than perfect each time
4. **Stay actionable**: Focus on "Ship" sections for practical learning
5. **Link everything**: Connect learning paths to projects and areas
6. **Review regularly**: Weekly reviews keep system effective

## Next Steps

After setting up:
1. Create your first inbox file with 5-10 resources
2. Run: `process learning from [your-file].md`
3. Review suggested clusters and approve
4. Explore generated learning paths
5. Start with "Ship" projects!

Happy learning! 🚀

