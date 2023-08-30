FROM ubuntu:jammy

RUN apt-get update && apt-get install python3-pip git -y
RUN python3 -m pip install -U pip
RUN python3 -m pip install mkdocs

RUN python3 -m pip install -U mkdocs-rebalance-theme==0.0.19 mkdocs-paginate-plugin>=0.0.6 mkdocs-mermaid2-plugin

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

EXPOSE 8000
WORKDIR /docs
