#!/bin/sh

# pdf-to-markdown: PDF in via STDIN, Markdown out via STDOUT.
#
# Designed to slot into a processing pipeline:
#
#   cat file.pdf | docker run --rm -i pdf-to-markdown > file.md
#   curl -s https://example.com/doc.pdf | docker run --rm -i pdf-to-markdown | pandoc -f markdown -t html
#
# Design notes:
# - docling's CLI takes a file path (no native STDIN support), so the PDF is
#   staged to a temp file and converted there.
# - ALL docling output (logs, progress) is redirected to STDERR, so STDOUT
#   carries nothing but the Markdown document.
# - Extra arguments are passed through to `docling convert`. Docling ignores
#   --quiet when --verbose is present, so the two never conflict.
# - `--embed-images false` switches STDOUT to a tar archive containing the
#   Markdown and an images/ directory.
#
# With no arguments and STDIN not a terminal, behaves as above. Otherwise
# prints the docling help.

set -e

# Keep embedded Markdown as the default. In archive mode, use referenced
# images and package the Markdown and image assets together on STDOUT.
ARCHIVE_IMAGES=0
if [ "$#" -ge 2 ] && [ "$1" = "--embed-images" ]; then
    case "$2" in
        true) shift 2 ;;
        false)
            ARCHIVE_IMAGES=1
            shift 2
            ;;
        *)
            echo "error: --embed-images must be true or false" >&2
            exit 2
            ;;
    esac
fi

# No args: print help only when STDIN is a terminal (interactive use).
# When STDIN is a pipe, fall through and treat the input as a PDF.
if [ "$#" -eq 0 ] && [ -t 0 ]; then
    docling --help
    exit 0
fi

# Stage STDIN (or a piped PDF) to a temp file for docling.
TMPDIR_STAGE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_STAGE"' EXIT
INPUT="$TMPDIR_STAGE/input.pdf"
cat > "$INPUT"

# Extra user args (if any) are in "$@".
if [ "$ARCHIVE_IMAGES" -eq 1 ]; then
    docling convert \
        --to md \
        --quiet \
        --output "$TMPDIR_STAGE/out" \
        "$@" \
        --image-export-mode referenced \
        "$INPUT" 1>&2

    OUTPUT_MD=$(find "$TMPDIR_STAGE/out" -maxdepth 1 -type f -name '*.md' -print -quit)
    if [ -z "$OUTPUT_MD" ]; then
        echo "error: Docling did not produce Markdown output" >&2
        exit 1
    fi

    ARCHIVE_DIR="$TMPDIR_STAGE/archive"
    mkdir -p "$ARCHIVE_DIR/images"
    sed "s|$TMPDIR_STAGE/out/input_artifacts/|images/|g" "$OUTPUT_MD" \
        > "$ARCHIVE_DIR/document.md"
    if [ -d "$TMPDIR_STAGE/out/input_artifacts" ]; then
        for IMAGE_FILE in "$TMPDIR_STAGE/out/input_artifacts/"*; do
            [ -f "$IMAGE_FILE" ] || continue
            cp "$IMAGE_FILE" "$ARCHIVE_DIR/images/"
        done
    fi
    tar -C "$ARCHIVE_DIR" -cf - document.md images
else
    docling convert \
        --to md \
        --quiet \
        --output "$TMPDIR_STAGE/out" \
        "$@" \
        "$INPUT" 1>&2

    # Emit the Markdown on STDOUT.
    cat "$TMPDIR_STAGE/out"/*.md
fi
