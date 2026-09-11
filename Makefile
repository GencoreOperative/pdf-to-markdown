# Makefile to build the pdf-to-markdown Docker image.
#
# Usage:
#   make build        Build the Docker image (tags latest + docling-<version>)
#   make convert      Convert a PDF to Markdown

DOCKER_IMAGE ?= pdf-to-markdown
DOCKERFILE_DIR := docker

# Build tags the image twice: latest, plus a tag carrying the docling version
# actually installed in the image (e.g. pdf-to-markdown:docling-2.126.0), so
# images can be pinned to a known-good docling release.
build:
	docker build -t $(DOCKER_IMAGE):latest $(DOCKERFILE_DIR)
	$(MAKE) retag

retag:
	@VERSION=$$(docker run --rm --entrypoint python $(DOCKER_IMAGE):latest -c "import importlib.metadata as m; print(m.version('docling'))"); \
	docker tag $(DOCKER_IMAGE):latest $(DOCKER_IMAGE):docling-$${VERSION}; \
	echo "tagged $(DOCKER_IMAGE):docling-$${VERSION}"

# Convert a PDF to Markdown:
#   make convert PDF=test/test.pdf
PDF ?= test/test.pdf
convert:
	./pdfToMarkdown $(PDF)
