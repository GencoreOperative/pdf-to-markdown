# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project overview

A Docker-based utility that converts PDF files to Markdown using
[Docling](https://github.com/docling-project/docling). PDFs go in via STDIN,
Markdown comes out via STDOUT, so it slots into processing pipelines.

## Key files

| File | Purpose |
|---|---|
| `docker/Dockerfile` | Image build: CPU-only torch pin, transformers 4.x pin, pre-cached model weights |
| `docker/entrypoint.sh` | Container entrypoint: STDIN → temp file → `docling convert` → STDOUT |
| `pdfToMarkdown` | Shell wrapper: takes a PDF path, pipes it to the image, writes `<name>.md` |
| `Makefile` | `make build` (tags `latest` + `docling-<version>`), `make convert PDF=...` |
| `test/test.pdf` | Sample PDF for end-to-end smoke testing |

## Key commands

```bash
make build               # build the image
./pdfToMarkdown test/test.pdf   # convert a PDF (writes test.md)
```

## When making changes

- Any change to the Dockerfile's pip install line invalidates the 1.4 GB model
  download layer — keep dependency changes in the same `RUN` as the rest of the
  pip install, and expect a full rebuild when they move.
- Document non-obvious build decisions (dependency pins, workarounds) in
  `README.md`, which is the project's decision log for the build.
