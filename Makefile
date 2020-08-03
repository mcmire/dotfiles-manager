.PHONY: build test
.DEFAULT: all

all: build test

build:
	scripts/build.sh

test:
	scripts/test.sh
