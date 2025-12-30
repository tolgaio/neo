#!/usr/bin/env bash
# Obsidian PDF Export - Main Orchestration Script
#
# Usage: export.sh [OPTIONS] <input> [output]
#
# Exports Obsidian notes to PDF using Docker-based Pandoc/LaTeX

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_IMAGE="obsidian-pdf-export"

# Defaults
VAULT_PATH="${BRAIN_HOME:-$HOME/src/tolgaio/brain}"
PAGE_SIZE="a4"
MARGIN="1in"
TOP_MARGIN=""
BOTTOM_MARGIN=""
TOC_DEPTH=3
INCLUDE_TOC=true
BATCH_MODE=false
ORDER_FILE=""
CUSTOM_TITLE=""
ENGINE="latex"  # latex or chromium
PRESET=""

# Device presets
apply_preset() {
    local preset="$1"
    case "$preset" in
        nomad|supernote)
            # Supernote Nomad: 1404x1872 @ 300 PPI = 4.7" x 6.2"
            PAGE_SIZE="4.7x6.2"
            MARGIN="0.3in"
            ;;
        remarkable|rm2)
            # reMarkable 2: 1404x1872 @ 226 PPI = 6.2" x 8.3"
            PAGE_SIZE="6.2x8.3"
            MARGIN="0.4in"
            ;;
        kindle)
            # Kindle Paperwhite: ~6" display
            PAGE_SIZE="3.5x5.5"
            MARGIN="0.2in"
            ;;
        a4)
            PAGE_SIZE="a4"
            MARGIN="1in"
            ;;
        letter)
            PAGE_SIZE="letter"
            MARGIN="1in"
            ;;
        *)
            error "Unknown preset: $preset. Available: nomad, remarkable, kindle, a4, letter"
            ;;
    esac
}

# ============================================================================
# FUNCTIONS
# ============================================================================

usage() {
    cat << 'EOF'
Obsidian PDF Export

Usage: export.sh [OPTIONS] <input> [output]

Arguments:
  input     Path to note or glob pattern (e.g., "1_Projects/myproject/*.md")
  output    Output PDF path (default: input_name.pdf in current dir)

Options:
  --vault PATH        Path to Obsidian vault (default: $BRAIN_HOME or ~/src/tolgaio/brain)
  --preset NAME       Device preset: nomad, remarkable, kindle, a4, letter
  --page-size SIZE    Page size: a4, letter, legal, or WxH in inches (default: a4)
  --margin SIZE       Page margin for all sides (default: 1in)
  --top-margin SIZE   Top margin (default: same as --margin)
  --bottom-margin SIZE Bottom margin (default: same as --margin)
  --no-toc            Disable table of contents
  --toc-depth N       TOC depth 1-6 (default: 3)
  --title TEXT        Custom PDF title (default: from frontmatter or filename)
  --batch             Batch mode: combine multiple notes into single PDF
  --order FILE        For batch: file listing note order (one path per line)
  --engine ENGINE     PDF engine: latex or chromium (default: latex)
  -h, --help          Show this help

Engines:
  latex     Professional typesetting via Pandoc/LaTeX (default)
  chromium  HTML/CSS rendering via Puppeteer (better emoji support)

Page Size Examples:
  --page-size a4          Standard A4 (210mm x 297mm)
  --page-size letter      US Letter (8.5in x 11in)
  --page-size legal       US Legal (8.5in x 14in)
  --page-size 6x9         Custom 6" x 9" (book format)
  --page-size 5.5x8.5     Half letter

Examples:
  # Single note export
  export.sh 1_Projects/myproject/README.md

  # Export with custom output path
  export.sh notes/idea.md ~/Desktop/idea.pdf

  # Batch export entire folder
  export.sh --batch "1_Projects/myproject/*.md" project-docs.pdf

  # Letter size with wider margins
  export.sh --page-size letter --margin 1.5in notes/report.md

  # Book format
  export.sh --page-size 6x9 --margin 0.75in manuscript.md book.pdf
EOF
}

log() {
    echo "[obsidian-pdf] $*" >&2
}

error() {
    echo "[obsidian-pdf] ERROR: $*" >&2
    exit 1
}

# Check if Docker image exists, build if not
ensure_docker_image() {
    local image_name="$1"
    local dockerfile="${2:-Dockerfile}"

    if ! docker image inspect "$image_name" &>/dev/null; then
        log "Docker image $image_name not found. Building..."
        docker build -f "$SKILL_DIR/docker/$dockerfile" -t "$image_name" "$SKILL_DIR/docker" || error "Failed to build Docker image"
        log "Docker image built successfully"
    fi
}

# Convert page size to geometry string
get_page_geometry() {
    local size="$1"

    case "$size" in
        a4|A4)
            echo "a4paper"
            ;;
        letter|Letter|LETTER)
            echo "letterpaper"
            ;;
        legal|Legal|LEGAL)
            echo "legalpaper"
            ;;
        *)
            # Check if it's WxH format (e.g., 6x9, 5.5x8.5)
            if [[ "$size" =~ ^([0-9]+\.?[0-9]*)x([0-9]+\.?[0-9]*)$ ]]; then
                local width="${BASH_REMATCH[1]}"
                local height="${BASH_REMATCH[2]}"
                echo "paperwidth=${width}in,paperheight=${height}in"
            else
                error "Invalid page size: $size. Use a4, letter, legal, or WxH (e.g., 6x9)"
            fi
            ;;
    esac
}

# Get output filename from input
get_output_name() {
    local input="$1"
    local basename

    if [[ "$BATCH_MODE" == "true" ]]; then
        basename="batch-export"
    else
        basename="$(basename "$input" .md)"
    fi

    echo "${basename}.pdf"
}

# Expand glob pattern to file list
expand_glob() {
    local pattern="$1"

    # Enable globstar for ** patterns
    shopt -s globstar nullglob

    # Expand the glob - use eval to handle patterns with spaces
    local files=()
    eval 'files=('"$pattern"')'

    # Restore shell options
    shopt -u globstar nullglob

    # Return files (one per line, properly handle spaces)
    if [[ ${#files[@]} -gt 0 ]]; then
        printf '%s\n' "${files[@]}"
    fi
}

# Process single note with LaTeX engine
process_single_latex() {
    local input="$1"
    local output="$2"
    local temp_dir="$3"

    # Preprocess the markdown
    python3 "$SCRIPT_DIR/preprocess.py" \
        --vault "$VAULT_PATH" \
        --output "$temp_dir/processed.md" \
        "$input"

    # Build geometry string
    local geometry
    geometry=$(get_page_geometry "$PAGE_SIZE")
    geometry="${geometry},margin=${MARGIN}"
    [[ -n "$TOP_MARGIN" ]] && geometry="${geometry},top=${TOP_MARGIN}"
    [[ -n "$BOTTOM_MARGIN" ]] && geometry="${geometry},bottom=${BOTTOM_MARGIN}"

    # Build pandoc arguments
    local pandoc_args=(
        "/workspace/processed.md"
        "-o" "/output/$(basename "$output")"
        "--template=obsidian"
        "--pdf-engine=xelatex"
        "-V" "geometry:$geometry"
    )

    # Add TOC if enabled
    if [[ "$INCLUDE_TOC" == "true" ]]; then
        pandoc_args+=("--toc" "--toc-depth=$TOC_DEPTH")
    fi

    # Add title if specified
    if [[ -n "$CUSTOM_TITLE" ]]; then
        pandoc_args+=("--metadata" "title=$CUSTOM_TITLE")
    fi

    # Create output directory
    local output_dir
    output_dir=$(dirname "$output")
    mkdir -p "$output_dir"

    # Run pandoc in Docker
    log "Generating PDF (LaTeX engine)..."
    docker run --rm \
        -v "$temp_dir:/workspace:ro" \
        -v "$output_dir:/output" \
        -v "$VAULT_PATH:/vault:ro" \
        obsidian-pdf-export \
        "${pandoc_args[@]}"
}

# Process single note with Chromium engine
process_single_chromium() {
    local input="$1"
    local output="$2"
    local temp_dir="$3"

    # Preprocess the markdown
    python3 "$SCRIPT_DIR/preprocess.py" \
        --vault "$VAULT_PATH" \
        --output "$temp_dir/processed.md" \
        "$input"

    # Build chromium arguments
    local chromium_args=(
        "/workspace/processed.md"
        "-o" "/output/$(basename "$output")"
        "--page-size" "$PAGE_SIZE"
        "--margin" "$MARGIN"
    )

    # Add TOC options
    if [[ "$INCLUDE_TOC" != "true" ]]; then
        chromium_args+=("--no-toc")
    else
        chromium_args+=("--toc-depth" "$TOC_DEPTH")
    fi

    # Add title if specified
    if [[ -n "$CUSTOM_TITLE" ]]; then
        chromium_args+=("--title" "$CUSTOM_TITLE")
    else
        # Extract title from filename
        local title
        title=$(basename "$input" .md | tr '-' ' ')
        chromium_args+=("--title" "$title")
    fi

    # Create output directory
    local output_dir
    output_dir=$(dirname "$output")
    mkdir -p "$output_dir"

    # Run chromium export in Docker
    log "Generating PDF (Chromium engine)..."
    docker run --rm \
        -v "$temp_dir:/workspace:ro" \
        -v "$output_dir:/output" \
        -v "$VAULT_PATH:/vault:ro" \
        obsidian-pdf-chromium \
        "${chromium_args[@]}"
}

# Process single note
process_single() {
    local input="$1"
    local output="$2"
    local temp_dir

    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    log "Processing: $input"

    # Make input path absolute
    if [[ "$input" != /* ]]; then
        if [[ -f "$VAULT_PATH/$input" ]]; then
            input="$VAULT_PATH/$input"
        elif [[ -f "$input" ]]; then
            input="$(pwd)/$input"
        else
            error "File not found: $input"
        fi
    fi

    # Process based on engine
    case "$ENGINE" in
        latex)
            process_single_latex "$input" "$output" "$temp_dir"
            ;;
        chromium)
            process_single_chromium "$input" "$output" "$temp_dir"
            ;;
        *)
            error "Unknown engine: $ENGINE. Use 'latex' or 'chromium'"
            ;;
    esac

    log "Created: $output"
}

# Process batch of notes - shared preprocessing
process_batch_preprocess() {
    local pattern="$1"
    local temp_dir="$2"

    # Get list of files
    local files
    if [[ -n "$ORDER_FILE" ]]; then
        # Use order file
        mapfile -t files < "$ORDER_FILE"
    else
        # Expand glob pattern
        mapfile -t files < <(expand_glob "$pattern")
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        error "No files match pattern: $pattern"
    fi

    log "Batch processing ${#files[@]} notes..."

    # Build title
    local title="${CUSTOM_TITLE:-Batch Export}"

    # Preprocess and merge
    python3 "$SCRIPT_DIR/preprocess.py" \
        --vault "$VAULT_PATH" \
        --batch \
        --title "$title" \
        --output "$temp_dir/processed.md" \
        "${files[@]}"

    # Return file count
    echo "${#files[@]}"
}

# Process batch with LaTeX engine
process_batch_latex() {
    local pattern="$1"
    local output="$2"
    local temp_dir="$3"
    local file_count

    file_count=$(process_batch_preprocess "$pattern" "$temp_dir")

    # Build geometry string
    local geometry
    geometry=$(get_page_geometry "$PAGE_SIZE")
    geometry="${geometry},margin=${MARGIN}"
    [[ -n "$TOP_MARGIN" ]] && geometry="${geometry},top=${TOP_MARGIN}"
    [[ -n "$BOTTOM_MARGIN" ]] && geometry="${geometry},bottom=${BOTTOM_MARGIN}"

    # Build pandoc arguments
    local pandoc_args=(
        "/workspace/processed.md"
        "-o" "/output/$(basename "$output")"
        "--template=obsidian"
        "--pdf-engine=xelatex"
        "-V" "geometry:$geometry"
    )

    # Add TOC if enabled
    if [[ "$INCLUDE_TOC" == "true" ]]; then
        pandoc_args+=("--toc" "--toc-depth=$TOC_DEPTH")
    fi

    # Create output directory
    local output_dir
    output_dir=$(dirname "$output")
    mkdir -p "$output_dir"

    # Run pandoc in Docker
    log "Generating PDF (LaTeX engine)..."
    docker run --rm \
        -v "$temp_dir:/workspace:ro" \
        -v "$output_dir:/output" \
        -v "$VAULT_PATH:/vault:ro" \
        obsidian-pdf-export \
        "${pandoc_args[@]}"

    log "Created: $output ($file_count notes)"
}

# Process batch with Chromium engine
process_batch_chromium() {
    local pattern="$1"
    local output="$2"
    local temp_dir="$3"
    local file_count

    file_count=$(process_batch_preprocess "$pattern" "$temp_dir")

    # Build chromium arguments
    local chromium_args=(
        "/workspace/processed.md"
        "-o" "/output/$(basename "$output")"
        "--page-size" "$PAGE_SIZE"
        "--margin" "$MARGIN"
    )

    # Add TOC options
    if [[ "$INCLUDE_TOC" != "true" ]]; then
        chromium_args+=("--no-toc")
    else
        chromium_args+=("--toc-depth" "$TOC_DEPTH")
    fi

    # Add title
    local title="${CUSTOM_TITLE:-Batch Export}"
    chromium_args+=("--title" "$title")

    # Create output directory
    local output_dir
    output_dir=$(dirname "$output")
    mkdir -p "$output_dir"

    # Run chromium export in Docker
    log "Generating PDF (Chromium engine)..."
    docker run --rm \
        -v "$temp_dir:/workspace:ro" \
        -v "$output_dir:/output" \
        -v "$VAULT_PATH:/vault:ro" \
        obsidian-pdf-chromium \
        "${chromium_args[@]}"

    log "Created: $output ($file_count notes)"
}

# Process batch of notes
process_batch() {
    local pattern="$1"
    local output="$2"
    local temp_dir

    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    # Process based on engine
    case "$ENGINE" in
        latex)
            process_batch_latex "$pattern" "$output" "$temp_dir"
            ;;
        chromium)
            process_batch_chromium "$pattern" "$output" "$temp_dir"
            ;;
        *)
            error "Unknown engine: $ENGINE. Use 'latex' or 'chromium'"
            ;;
    esac
}

# ============================================================================
# MAIN
# ============================================================================

# Parse arguments
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --vault)
            VAULT_PATH="$2"
            shift 2
            ;;
        --preset)
            PRESET="$2"
            apply_preset "$PRESET"
            shift 2
            ;;
        --page-size)
            PAGE_SIZE="$2"
            shift 2
            ;;
        --margin)
            MARGIN="$2"
            shift 2
            ;;
        --top-margin)
            TOP_MARGIN="$2"
            shift 2
            ;;
        --bottom-margin)
            BOTTOM_MARGIN="$2"
            shift 2
            ;;
        --no-toc)
            INCLUDE_TOC=false
            shift
            ;;
        --toc-depth)
            TOC_DEPTH="$2"
            shift 2
            ;;
        --title)
            CUSTOM_TITLE="$2"
            shift 2
            ;;
        --batch)
            BATCH_MODE=true
            shift
            ;;
        --order)
            ORDER_FILE="$2"
            shift 2
            ;;
        --engine)
            ENGINE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"

# Validate arguments
if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-$(pwd)/$(get_output_name "$INPUT")}"

# Make output path absolute
if [[ "$OUTPUT" != /* ]]; then
    OUTPUT="$(pwd)/$OUTPUT"
fi

# Ensure Docker image is available based on engine
case "$ENGINE" in
    latex)
        ensure_docker_image "obsidian-pdf-export" "Dockerfile"
        ;;
    chromium)
        ensure_docker_image "obsidian-pdf-chromium" "Dockerfile.chromium"
        ;;
    *)
        error "Unknown engine: $ENGINE. Use 'latex' or 'chromium'"
        ;;
esac

# Process based on mode
if [[ "$BATCH_MODE" == "true" ]]; then
    process_batch "$INPUT" "$OUTPUT"
else
    process_single "$INPUT" "$OUTPUT"
fi
