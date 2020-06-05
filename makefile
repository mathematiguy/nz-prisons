DOCKER_REGISTRY := mathematiguy
IMAGE_NAME := $(shell basename `git rev-parse --show-toplevel` | tr '[:upper:]' '[:lower:]')
IMAGE := $(DOCKER_REGISTRY)/$(IMAGE_NAME)
HAS_DOCKER ?= $(shell which docker)
RUN ?= $(if $(HAS_DOCKER),docker run $(DOCKER_ARGS) --rm -v $$(pwd):/code -w /code -u $(UID):$(GID) $(IMAGE))
UID ?= $(shell id -u)
GID ?= $(shell id -g)
DOCKER_ARGS ?= 
GIT_TAG ?= $(shell git log --oneline | head -n1 | awk '{print $$1}')

.PHONY: data docker docker-push docker-pull enter enter-root

notebooks: $(shell ls -d analysis/*.Rmd | sed 's/.Rmd/.pdf/g')

data: data/processed/prison_pop.csv data/processed/demographics.csv data/processed/pop_estimates.csv

data/processed/%.csv: scripts/prepare_%.R data/raw/%.csv
	$(RUN) Rscript $<

data/processed/demographics.csv: scripts/prepare_demographics.R data/raw/demographics.csv data/processed/prison_pop.csv
	$(RUN) Rscript $<

data/raw/%.csv: data/raw/%.zip
	unzip -o $< -d $(dir $@) && touch $@

analysis/%.pdf: analysis/%.Rmd
	$(RUN) Rscript -e 'rmarkdown::render("$<")'

daemon: DOCKER_ARGS= -dit --rm -e DISPLAY=$$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro --name="rdev"
daemon:
	$(RUN) R

clean:
	rm -rf analysis/*.pdf analysis/*.aux analysis/*.bcf analysis/*.knit.md \
	analysis/*.out analysis/*.run.xml analysis/*.utf8.md analysis/*.rds analysis/*.bib \
	analysis/*_files analysis/*.log analysis/*.lot analysis/*.toc analysis/*.lof \
	models/*.rds data/raw/*.csv data/processed/*.csv

.PHONY: docker
docker:
	docker build $(DOCKER_ARGS) --tag $(IMAGE):$(GIT_TAG) .
	docker tag $(IMAGE):$(GIT_TAG) $(IMAGE):latest

.PHONY: docker-push
docker-push:
	docker push $(IMAGE):$(GIT_TAG)
	docker push $(IMAGE):latest

.PHONY: docker-pull
docker-pull:
	docker pull $(IMAGE):$(GIT_TAG)
	docker tag $(IMAGE):$(GIT_TAG) $(IMAGE):latest

.PHONY: enter
enter: DOCKER_ARGS=-it
enter:
	$(RUN) bash

.PHONY: enter-root
enter-root: DOCKER_ARGS=-it
enter-root: UID=root
enter-root: GID=root
enter-root:
	$(RUN) bash
