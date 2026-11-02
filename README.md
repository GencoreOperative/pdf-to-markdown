# pdf-to-markdown

Convert PDF files to Markdown using [Docling](https://github.com/docling-project/docling),
packaged as a self-contained Docker image.

The image is designed to be a pipeline component: **PDF in via STDIN, Markdown
out via STDOUT**, with all logs on STDERR.

## Quick start

```bash
make build                       # build the image (downloads ~1.4 GB of model weights)
./pdfToMarkdown mydoc.pdf        # convert; writes mydoc.md in the current folder
```

`make build` tags the image twice: `pdf-to-markdown:latest` and a version tag
naming the docling release actually installed in the image, e.g.
`pdf-to-markdown:docling-2.126.0` (read from inside the image, so the tag can
never drift from the build). Pin to the version tag for reproducible builds.

Pushing to Docker Hub (`gencore/pdf-to-markdown`) pushes both tags:

```bash
docker login        # once per machine
make push           # pushes gencore/pdf-to-markdown:latest + :docling-<version>
```

Override the destination with `PUSH_IMAGE=<namespace>/<repo> make push`.

Equivalent manual pipeline:

```bash
cat mydoc.pdf | docker run --rm -i pdf-to-markdown > mydoc.md
```

To omit images from the Markdown, use `--no-images`:

```bash
./pdfToMarkdown --no-images mydoc.pdf
```

This selects Docling's `placeholder` image export mode: the Markdown marks
where images appeared but does not embed image data or export separate image
files. Without the flag, images are embedded in the Markdown by default.

Override the image with `PDF_TO_MARKDOWN_IMAGE=name:tag`.

## Usage

```
pdfToMarkdown [--no-images] <file.pdf>
```

Writes `<file.md>` (input stem + `.md`) in the current folder. A failed
conversion never leaves a truncated output file.

Note: Docling's default `--image-export-mode embedded` inlines every image in
the PDF as base64, which can make outputs much larger than the source. Use
`--no-images` for text-processing pipelines that do not need image content.

## The image

The image is fully self-contained: model weights are baked in at build time
(`docling-tools models download`, ~1.4 GB under `/root/.cache/docling/models`),
so conversion works offline — no network access needed at run time.

| Layer | Size | Contents |
|---|---|---|
| pip install | ~1.8 GB | docling + CPU-only PyTorch tree |
| model download | ~1.4 GB | layout, table-structure, code-formula, OCR, figure-classifier weights |
| apt packages | ~0.2 GB | native libs for OpenCV (`libgl1`, `libglib2.0-0`) |

Total image size: ~1.9 GB (content), ~5.5 GB on disk with containerd's
decompressed layers.

## The PyTorch CPU trick

A naive `pip install docling` pulls in the full CUDA-enabled PyTorch stack —
`nvidia-cudnn`, `nvidia-cublas`, `nvidia-nccl` and friends — adding several
gigabytes that this image will never use, since conversion runs on CPU only.

Docling constrains torch loosely (`torch>=2.2.2,<3.0.0`, via
`docling-ibm-models`), which gives the resolver room to accept an older
torch, and pip can be pointed at PyTorch's CPU-only wheel index. The result:
torch's entire CUDA dependency tree is replaced by a single self-contained
wheel.

The practical pin set in `docker/Dockerfile`:

```dockerfile
RUN pip install --no-cache-dir \
    docling \
    "torch==2.4.1+cpu" \
    "torchvision==0.19.1+cpu" \
    "transformers>=4.42.0,<5.0.0" \
    --extra-index-url https://download.pytorch.org/whl/cpu
```

The decisions behind each line, and the dead ends we hit:

- **`--extra-index-url .../whl/cpu`, not `-f .../torch_stable.html`.** The
  commonly-cited legacy `torch_stable.html` links page stopped carrying
  `+cpu` wheels newer than 2.3.1; the real PEP 503 index at
  `https://download.pytorch.org/whl/cpu` serves the full set. Because the
  `+cpu` local version is pinned exactly, PyPI's CUDA-bundled bare `torch`
  can never be selected.
- **torch 2.4.1, not 2.3.1.** Older is smaller, but torch 2.3.x was compiled
  against NumPy 1.x and fails at import time against the numpy 2.x that the
  rest of docling's tree resolves. torch 2.4.0 is the first version with
  native NumPy 2 support, so no `numpy<2` pin is needed. (2.4.1 is the last
  2.4.x patch release.)
- **transformers 4.x pin.** The naturally-resolved transformers 5.x requires
  PyTorch >= 2.5 and disables itself on 2.4.1 ("Disabling PyTorch because
  PyTorch >= 2.5 is required"). docling-ibm-models accepts
  `transformers>=4.42,<6` and was originally built against the 4.x line, so
  pinning 4.x keeps the old torch. If docling ever needs transformers 5
  features, the fallback is torch 2.5.1+cpu with no transformers pin.
- **No `--no-deps` gymnastics.** Docling's loose torch constraint lets pip
  resolve the entire tree normally with the pins in place. This is cleaner
  than hand-deriving the dependency list (the approach some projects need,
  e.g. forcing whisperx onto torch 2.3.1+cpu by installing the tree with
  docling's deps first and whisperx with `--no-deps`).
- **Python 3.12 base, not 3.14.** CPU-only torch wheels for Python 3.14 start
  at torch 2.9.0, so pinning an old torch forces Python <= 3.12. docling 2.126
  supports 3.10–3.14; 3.12 is the safe choice. This constraint disappears if
  we ever move to newest-torch (which also comes CPU-only via the same index).

## Model pre-caching

`docling-tools models download` fetches the default model set into
`/root/.cache/docling/models` at build time. Two gotchas we hit:

- The tool ignores `DOCLING_ARTIFACTS_PATH` — it always downloads to its
  default path. The env var is therefore set *after* the download layer and
  only matters at convert time, which also keeps the big download layer's
  cache key stable across env changes.
- `DOCLING_ARTIFACTS_PATH` must match where the weights actually are
  (`/root/.cache/docling/models`), or docling re-downloads at run time.

## Project layout

```
docker/Dockerfile      image build
docker/entrypoint.sh   STDIN -> temp file -> docling convert -> STDOUT
pdfToMarkdown          shell wrapper (PDF path -> <stem>.md)
Makefile               make build / make convert
test/test.pdf          sample PDF for smoke testing
```

## Limitations

- Python 3.12 is forced by the old-torch pin (see the PyTorch CPU trick).
- The pin set is a point-in-time resolution: docling, transformers and
  docling-ibm-models all move independently, so a future docling release may
  need the pins revisited (the documented fallbacks above).
- Docling's CLI has no native STDIN support, so the entrypoint stages input to
  a temp file — a large PDF exists on disk inside the container for the
  duration of the conversion.
