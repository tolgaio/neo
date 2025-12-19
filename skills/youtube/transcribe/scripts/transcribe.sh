#!/bin/bash
#
# YouTube Transcription Script
# Extracts subtitles/captions from YouTube videos using yt-dlp via Docker
#
# Usage: ./transcribe.sh [--timestamps] <youtube_url>
#
# Options:
#   --timestamps    Include [HH:MM:SS] timestamps in output
#
# Dependencies:
#   - Docker
#   - jauderho/yt-dlp image

set -e

# Parse arguments
TIMESTAMPS=false
URL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --timestamps|-t)
            TIMESTAMPS=true
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            URL="$1"
            shift
            ;;
    esac
done

if [[ -z "$URL" ]]; then
    echo "Usage: $0 [--timestamps] <youtube_url>" >&2
    exit 1
fi

# Extract video ID from URL
VIDEO_ID=""
if [[ "$URL" =~ youtube\.com/watch\?v=([a-zA-Z0-9_-]+) ]]; then
    VIDEO_ID="${BASH_REMATCH[1]}"
elif [[ "$URL" =~ youtu\.be/([a-zA-Z0-9_-]+) ]]; then
    VIDEO_ID="${BASH_REMATCH[1]}"
elif [[ "$URL" =~ youtube\.com/embed/([a-zA-Z0-9_-]+) ]]; then
    VIDEO_ID="${BASH_REMATCH[1]}"
elif [[ "$URL" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    # Assume it's just a video ID
    VIDEO_ID="$URL"
else
    echo "Error: Could not extract video ID from URL: $URL" >&2
    exit 1
fi

# Create temp directory for output
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# Run yt-dlp via Docker to download subtitles
# Note: yt-dlp may return non-zero even on partial success (e.g., some subtitle variants fail)
# We check for VTT files afterward to determine actual success
docker run --rm \
    -v "$WORK_DIR:/output" \
    jauderho/yt-dlp \
    --write-auto-subs \
    --skip-download \
    --sub-format vtt \
    --sub-langs "en.*,en" \
    -o "/output/%(id)s.%(ext)s" \
    "https://www.youtube.com/watch?v=$VIDEO_ID" \
    >/dev/null 2>&1 || true

# Find the VTT file
VTT_FILE=$(find "$WORK_DIR" -name "*.vtt" -type f | head -1)

if [[ -z "$VTT_FILE" || ! -f "$VTT_FILE" ]]; then
    echo "Error: No subtitles found for video $VIDEO_ID" >&2
    echo "The video may not have captions available." >&2
    exit 1
fi

# Process VTT file
process_vtt() {
    local vtt_file="$1"
    local with_timestamps="$2"

    if [[ "$with_timestamps" == "true" ]]; then
        # Output with timestamps in [HH:MM:SS] format
        awk '
        BEGIN { last_text = ""; current_time = "" }
        # Capture timestamp from timing line
        /^[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+ -->/ {
            split($1, t, ".")
            current_time = t[1]
            next
        }
        # Skip VTT header and metadata
        /^WEBVTT/ { next }
        /^Kind:/ { next }
        /^Language:/ { next }
        /^NOTE/ { next }
        /^$/ { next }
        {
            # Clean the text
            gsub(/<[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+>/, "")  # Remove inline timestamps
            gsub(/<\/?c>/, "")  # Remove <c> tags
            gsub(/<[^>]*>/, "")  # Remove other HTML-like tags
            gsub(/align:start position:[0-9]+%/, "")  # Remove positioning
            gsub(/&nbsp;/, " ")
            gsub(/&amp;/, "\\&")
            gsub(/&lt;/, "<")
            gsub(/&gt;/, ">")
            gsub(/^[ \t]+|[ \t]+$/, "")  # Trim whitespace

            # Deduplicate consecutive identical lines
            if ($0 != "" && $0 != last_text && current_time != "") {
                print "[" current_time "] " $0
                last_text = $0
            }
        }
        ' "$vtt_file"
    else
        # Output clean text without timestamps
        awk '
        BEGIN { last_text = "" }
        # Skip VTT header and metadata
        /^WEBVTT/ { next }
        /^Kind:/ { next }
        /^Language:/ { next }
        /^NOTE/ { next }
        /^$/ { next }
        # Skip timestamp lines
        /^[0-9]{2}:[0-9]{2}:[0-9]{2}/ { next }
        {
            # Clean the text
            gsub(/<[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+>/, "")  # Remove inline timestamps
            gsub(/<\/?c>/, "")  # Remove <c> tags
            gsub(/<[^>]*>/, "")  # Remove other HTML-like tags
            gsub(/align:start position:[0-9]+%/, "")  # Remove positioning
            gsub(/&nbsp;/, " ")
            gsub(/&amp;/, "\\&")
            gsub(/&lt;/, "<")
            gsub(/&gt;/, ">")
            gsub(/^[ \t]+|[ \t]+$/, "")  # Trim whitespace

            # Deduplicate consecutive identical lines
            if ($0 != "" && $0 != last_text) {
                print $0
                last_text = $0
            }
        }
        ' "$vtt_file"
    fi
}

process_vtt "$VTT_FILE" "$TIMESTAMPS"
