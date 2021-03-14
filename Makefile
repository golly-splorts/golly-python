include common.mk

MODULES=golly_python

CB := $(shell git branch --show-current)

all:
	@echo "no default make rule defined"

help:
	cat Makefile

lint:
	flake8 $(MODULES)

mypy:
	mypy --ignore-missing-imports --no-strict-optional $(MODULES)

requirements:
	python3 -m pip install --upgrade -r requirements.txt

requirements-dev:
	python3 -m pip install --upgrade -r requirements-dev.txt

build: clean
	CYTHONIZE=1 python3 setup.py build

install:
	CYTHONIZE=1 pip3 install .

test: requirements-dev build
	pytest

release_main:
	@echo "Releasing current branch $(CB) to main"
	scripts/release.sh $(CB) main

clean:
	$(RM) -fr build dist __pycache__ *.egg-info/
	$(RM) -r golly_python/pylife.c
	find . -name __pycache__ -exec rm -r {} +

uninstall:
	pip uninstall golly_python
