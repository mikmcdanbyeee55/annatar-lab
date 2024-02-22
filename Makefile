GLAB_CMD   ?= glab
IMAGE_NAME ?= annatar
IMAGE_TAG  ?= latest
BUILD_ARCH ?= linux/amd64
ARCHS       = amd64 arm64

ifdef CI_REGISTRY_IMAGE
	IMAGE_NAME := $(CI_REGISTRY_IMAGE)
endif

ARCH_SUFFIX       = $(shell echo $(BUILD_ARCH) | cut -d '/' -f2)
DOCKERFILE       ?= Dockerfile
DOCKER_PUSH      ?= --load # set this to --push to push --load to load it into the local registry
DOCKER_TAG       := $(IMAGE_NAME):$(IMAGE_TAG)
DOCKER_TAG_ARCH  := $(DOCKER_TAG)-$(ARCH_SUFFIX)

PYTEST_FLAGS ?= 

CURRENT_GIT_TAG  = $(shell git describe --tags --abbrev=0)
RELEASE_VERSION ?= $(shell git describe --tags --abbrev=0 | awk -F. '{print $$1 "." $$2 "." $$3+1}')

# Build and push container for BUILD_ARCH
container:
	docker build --platform $(BUILD_ARCH) \
		--build-arg BUILD_VERSION=$(shell git describe --tags) \
		$(DOCKER_PUSH) \
		--cache-from=$(DOCKER_TAG_ARCH) \
		-f $(DOCKERFILE) \
		-t $(DOCKER_TAG_ARCH) .


# Create and push the docker manifest for all architectures
docker-manifest:
	docker manifest create $(DOCKER_TAG) $(foreach arch,$(ARCHS),$(DOCKER_TAG)-$(arch))
	$(foreach arch,$(ARCHS),docker manifest annotate $(DOCKER_TAG) $(DOCKER_TAG)-$(arch) --arch $(arch) ;)
	docker manifest push $(DOCKER_TAG)

test:
	poetry run ruff format --check --diff annatar
	poetry run ruff check annatar
	poetry run isort --check --diff annatar run.py
	poetry run black --check --diff annatar run.py
	poetry run pyright annatar
	poetry run pytest $(PYTEST_FLAGS)

.PHONY: confirm
confirm:
	@echo -n "Proceed? [y/N] " && read ans && [ $${ans:-N} = y ]

.INTERMEDIATE: RELEASE_NOTES.txt
RELEASE_NOTES.txt:
	git fetch --tags
	@git log --graph --format='%h - %s' \
		--abbrev-commit $(CURRENT_GIT_TAG)..HEAD \
		> $@

release: RELEASE_NOTES.txt
	@echo
	@echo -e "Version: $(RELEASE_VERSION)\nRelease Notes:"
	@cat $<
	@echo
	@$(MAKE) --no-print-directory confirm
	$(GLAB_CMD) release create $(RELEASE_VERSION) \
		-r master \
		--name "$(RELEASE_VERSION)" \
		--notes-file $<
	@git fetch --tags

