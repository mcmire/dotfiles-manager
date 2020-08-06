.PHONY: build test

all: test

build:
	scripts/build.sh

test:
	scripts/test.sh
