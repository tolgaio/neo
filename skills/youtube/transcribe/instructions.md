# YouTube Transcription Instructions

## Overview

This skill extracts subtitles/auto-captions from YouTube videos using yt-dlp via Docker.

## Prerequisites

- Docker must be installed and running
- The `jauderho/yt-dlp` Docker image will be pulled automatically on first use

## Usage

### Basic Transcription (Clean Text)

Run the transcription script with a YouTube URL:

```bash
skills/youtube/transcribe/scripts/transcribe.sh "https://www.youtube.com/watch?v=VIDEO_ID"
```

This outputs clean text without timestamps, ideal for summarization or AI processing.

### With Timestamps

Add the `--timestamps` flag to include `[HH:MM:SS]` timestamps:

```bash
skills/youtube/transcribe/scripts/transcribe.sh --timestamps "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Supported URL Formats

The script accepts various YouTube URL formats:
- `https://www.youtube.com/watch?v=VIDEO_ID`
- `https://youtu.be/VIDEO_ID`
- `https://www.youtube.com/embed/VIDEO_ID`
- Just the video ID: `VIDEO_ID`

## Workflow

When a user requests a YouTube video transcription:

1. **Extract the URL** from the user's request
2. **Run the transcription script** using Bash
3. **Review the output** - if no captions are available, inform the user
4. **Present the transcript** to the user or pipe it to another skill

## Example Workflows

### Transcribe and Summarize

```bash
# Get transcript
skills/youtube/transcribe/scripts/transcribe.sh "https://www.youtube.com/watch?v=dQw4w9WgXcQ" > /tmp/transcript.txt

# Then use a summarization skill on the transcript
```

### Get Timestamped Transcript

```bash
skills/youtube/transcribe/scripts/transcribe.sh --timestamps "https://youtu.be/dQw4w9WgXcQ"
```

## Error Handling

The script will fail if:
- The video doesn't have captions/subtitles
- The video is private or age-restricted
- Docker is not running
- Network connectivity issues

When errors occur, inform the user about the specific issue and suggest alternatives (e.g., using a different video or checking if captions are available).

## Output Format

### Clean Text (Default)
```
Hello and welcome to this video
Today we're going to discuss an important topic
Let me start by explaining the background
```

### With Timestamps
```
[00:00:00] Hello and welcome to this video
[00:00:03] Today we're going to discuss an important topic
[00:00:08] Let me start by explaining the background
```
