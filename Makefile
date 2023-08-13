POSTDIR=dailyocc/posts
POSTROOT=$(PWD)/$(POSTDIR)
HOSTURL=https://dailyoccupy.com
DOCKERIMG=ghcr.io/kubilus1/newsgen:latest

YEAR= $(shell date +%Y)
MONTH=  $(shell date +%m)
DAY = $(shell date +%d)

POSTPATH=$(POSTROOT)/$(YEAR)/$(MONTH)/$(DAY)
DBPATH=$(PWD)/data/db

build_img:
	docker-compose build

build_doc: build_img
	docker-compose run mkdocs /bin/bash -c "mkdocs build"

serve: build_img
	docker-compose run --service-ports mkdocs /bin/bash -c "mkdocs -v serve -a 0.0.0.0:8000"

clean:
	rm -rf build
