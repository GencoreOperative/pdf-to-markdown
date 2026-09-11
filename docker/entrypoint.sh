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
# - Extra arguments are passed through to `docling convert` (e.g. --verbose
#   or --image-export-mode). Docling ignores --quiet when --verbose is
#   present, so the two never conflict.
#
# With no arguments and STDIN not a terminal, behaves as above. Otherwise
# prints the docling help.

set -e

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
docling convert \
    --to md \
    --quiet \
    --output "$TMPDIR_STAGE/out" \
    "$@" \
    "$INPUT" 1>&2

# Emit the Markdown on STDOUT.
cat "$TMPDIR_STAGE/out"/*.md
