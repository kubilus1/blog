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
	#docker build -t mkdocst .
	docker-compose build

build_doc: build_img
	#docker-compose run --build --rm web mkdocs build
	#docker run -i --rm -v `pwd`:/docs mkdocst /bin/bash -c "mkdocs build"
	docker-compose run mkdocs /bin/bash -c "mkdocs build"

serve: build_img
	docker-compose run --service-ports mkdocs /bin/bash -c "mkdocs -v serve -a 0.0.0.0:8000"
	#docker run -p 8000:8000 -it --rm -v `pwd`:/docs mkdocst /bin/bash -c "mkdocs -v serve -a 0.0.0.0:8000"

clean:
	rm -rf build
