# YouTube Skills

Custom skills for working with YouTube content.

## Available Skills

| Skill | Description |
|-------|-------------|
| [transcribe](./transcribe/) | Extract subtitles/captions from YouTube videos |

## Usage

Use the `/youtube-transcribe` command to transcribe a video:

```
/youtube-transcribe https://www.youtube.com/watch?v=VIDEO_ID
```

## Dependencies

- Docker (for running yt-dlp)
- `jauderho/yt-dlp` Docker image (pulled automatically)
