# Makefile to build the pdf-to-markdown Docker image.
#
# Usage:
#   make build        Build the Docker image (tags latest + docling-<version>)
#   make retag        Re-apply the version and registry tags to the local image
#   make push         Push the image to the registry (both tags)
#   make convert      Convert a PDF to Markdown
#
# Pushing requires a prior `docker login`.

DOCKER_IMAGE ?= pdf-to-markdown
# Registry namespace to push to, e.g. docker.io/gencore/pdf-to-markdown.
PUSH_IMAGE ?= gencore/pdf-to-markdown
DOCKERFILE_DIR := docker

.PHONY: build retag push convert

# Build tags the image twice: latest, plus a tag carrying the docling version
# actually installed in the image (e.g. pdf-to-markdown:docling-2.126.0), so
# images can be pinned to a known-good docling release.
build:
	docker build -t $(DOCKER_IMAGE):latest $(DOCKERFILE_DIR)
	$(MAKE) retag

# Query the docling version installed inside the image and tag it under both
# the local name and the registry name, with both latest and the version tag.
# Shared by build and push so the two always agree.
retag:
	@VERSION=$$(docker run --rm --entrypoint python $(DOCKER_IMAGE):latest -c "import importlib.metadata as m; print(m.version('docling'))"); \
	docker tag $(DOCKER_IMAGE):latest $(DOCKER_IMAGE):docling-$${VERSION}; \
	docker tag $(DOCKER_IMAGE):latest $(PUSH_IMAGE):latest; \
	docker tag $(DOCKER_IMAGE):latest $(PUSH_IMAGE):docling-$${VERSION}; \
	echo "tagged docling-$${VERSION} for $(DOCKER_IMAGE) and $(PUSH_IMAGE)"

# Push both tags to the registry. Depends on retag so it works standalone.
push: retag
	docker push $(PUSH_IMAGE):latest
	docker push $(PUSH_IMAGE):docling-$$(docker run --rm --entrypoint python $(DOCKER_IMAGE):latest -c "import importlib.metadata as m; print(m.version('docling'))")

# Convert a PDF to Markdown:
#   make convert PDF=test/test.pdf
PDF ?= test/test.pdf
convert:
	./pdfToMarkdown $(PDF)
