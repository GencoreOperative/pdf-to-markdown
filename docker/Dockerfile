FROM python:3.12-slim

# ---------------------------------
# Install docling with CPU-only torch
# ---------------------------------
# Docling's torch constraint is generous (>=2.2.2,<3.0.0 via docling-ibm-models),
# so we can pin an old CPU-only torch directly and let pip resolve the rest of
# the dependency tree normally. This is much cleaner than installing docling
# with --no-deps and hand-deriving its dependencies.
#
# Why not torch 2.3.1 (which worked for whisperx)? Torch 2.3.x was compiled
# against NumPy 1.x and fails at import time when pip resolves numpy 2.x
# (which the rest of docling's tree does). Torch 2.4.0 is the first version
# that supports NumPy 2 natively, so no numpy pin is needed.
#
# The resolved transformers (5.x) requires PyTorch >= 2.5, so we pin
# transformers to the 4.x line, which docling-ibm-models also accepts
# (>=4.42.0,<6.0.0) and was originally built against. If this ever breaks,
# the fallback is torch 2.5.1+cpu with no transformers pin.
#
# Why python:3.12-slim rather than 3.14-slim? CPU-only torch wheels for
# Python 3.14 start at torch 2.9.0, so pinning an old torch forces Python
# 3.12. Note this is only an issue while we pin old torch; python:3.14-slim
# works fine with the default (newest) torch.
#
# --extra-index-url points pip at the torch CPU wheel index; all other
# packages come from PyPI as usual. The exact +cpu pins mean PyPI's
# (CUDA-bundled) bare torch can never be selected. (The legacy
# https://download.pytorch.org/whl/cpu/torch_stable.html links page no longer
# carries +cpu wheels newer than 2.3.1, so use the real index.)
RUN pip install --no-cache-dir \
    docling \
    "torch==2.4.1+cpu" \
    "torchvision==0.19.1+cpu" \
    "transformers>=4.42.0,<5.0.0" \
    --extra-index-url https://download.pytorch.org/whl/cpu

# Native libs docling needs at runtime (opencv via docling-ibm-models)
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------
# Pre-cache the docling model artifacts
# ---------------------------------
# Bake the model weights into the image so it is fully self-contained: no
# network access is needed at convert time. docling-tools always downloads to
# its default path (/root/.cache/docling/models) and ignores
# DOCLING_ARTIFACTS_PATH, so the env var is set AFTER the download — it only
# matters at convert time.
RUN docling-tools models download
ENV DOCLING_ARTIFACTS_PATH=/root/.cache/docling/models

# Keep any remaining caches out of the image layers
ENV HF_HOME=/tmp/ \
    TORCH_HOME=/tmp/ \
    OMP_NUM_THREADS=4

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
