#!/usr/bin/env bash

scripts/build.sh
exec ./test/libs/bats-core/bin/bats test "$@"
