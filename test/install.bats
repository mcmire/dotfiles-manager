#!/usr/bin/env ./test/libs/bats-core/bin/bats

load "libs/bats-support/load"
load "libs/bats-assert/load"

absolute-path-of() {
  echo $(cd "$(dirname "$1")" &>/dev/null && pwd)/$(basename "$1")
}

DOTFILES=$(absolute-path-of tmp/dotfiles)
export DOTFILES_HOME=$(absolute-path-of tmp/dotfiles-home)

scripts/build.sh

setup() {
  rm -rf "$DOTFILES_HOME"
  mkdir "-p" $DOTFILES_HOME

  rm -rf "$DOTFILES"
  mkdir -p "$DOTFILES/bin"
  mkdir -p "$DOTFILES/src"
  cp build/manage "$DOTFILES/bin/manage"
  chmod +x "$DOTFILES/bin/manage"
  cd "$DOTFILES"
}

@test "installs files in src/ to symlinks in HOME, adding the dot" {
  touch src/some-file

  run bin/manage install
  assert_success

  assert [ -L "$DOTFILES_HOME/.some-file" ]
  assert_equal "$(readlink "$DOTFILES_HOME/.some-file")" "$DOTFILES/src/some-file"
}

@test "does not install symlinks for files directly in src/ when --dry-run given" {
  touch src/some-file

  run bin/manage install --dry-run
  assert_success

  refute [ -e "$DOTFILES_HOME/.some-file" ]
}

@test "descends into subdirectories in src/ by default and symlinks files inside, adding the dot to the top-level directory" {
  mkdir -p src/foo/bar
  touch src/foo/bar/some-file

  run bin/manage install
  assert_success

  assert [ -L "$DOTFILES_HOME/.foo/bar/some-file" ]
  assert_equal "$(readlink "$DOTFILES_HOME/.foo/bar/some-file")" "$DOTFILES/src/foo/bar/some-file"
}

@test "does not install symlinks for files deep in src/ when --dry-run given" {
  mkdir -p src/foo/bar
  touch src/foo/bar/some-file

  run bin/manage install --dry-run
  assert_success

  refute [ -e "$DOTFILES_HOME/.foo/bar/some-file" ]
}

@test "does not descend into subdirectories that have a .no-recurse file present, instead symlinking the whole directory" {
  mkdir -p src/foo/bar
  touch src/foo/.no-recurse
  touch src/foo/bar/some-file

  run bin/manage install
  assert_success

  assert [ -L "$DOTFILES_HOME/.foo" ]
  assert_equal "$(readlink "$DOTFILES_HOME/.foo")" "$DOTFILES/src/foo"
  assert [ -f "$DOTFILES_HOME/.foo/bar/some-file" ]
}

@test "runs _install.sh in a directory after processing all files in it but before descending into subdirectories" {
  mkdir -p src/foo/baz
  touch src/foo/bar
  touch src/foo/baz/.no-recurse
  touch src/foo/baz/qux
  cat <<SCRIPT > src/foo/_install.sh
#!/usr/bin/env bash

echo hello > "$DOTFILES_HOME/.foo/bar"
if [[ -d "$DOTFILES_HOME/.foo/baz" ]]; then
  echo hello > "$DOTFILES_HOME/.foo/baz/qux"
fi
SCRIPT
  chmod +x src/foo/_install.sh

  run bin/manage install
  assert_success

  assert_equal hello "$(< "$DOTFILES_HOME/.foo/bar")"
  assert_equal "" "$(< "$DOTFILES_HOME/.foo/baz/qux")"
}

@test "does not run _install.sh when --dry-run given" {
  cat <<SCRIPT > src/_install.sh
#!/usr/bin/env bash

echo hello > "$DOTFILES_HOME/.foo"
SCRIPT
  chmod +x src/_install.sh

  run bin/manage install --dry-run
  assert_success

  refute [ -e "$DOTFILES_HOME/.foo" ]
}

@test "does not overwrite a file that is in the way of a future file symlink" {
  touch src/foo
  touch "$DOTFILES_HOME/.foo"

  run bin/manage install
  assert_success

  refute [ -L $DOTFILES_HOME/.foo ]
}

@test "overwrites a file in the way of a future symlink when --force given" {
  touch src/foo
  touch $DOTFILES_HOME/.foo

  run bin/manage install --force
  assert_success

  assert [ -L "$DOTFILES_HOME/.foo" ]
  assert_equal "$(readlink "$DOTFILES_HOME/.foo")" "$DOTFILES/src/foo"
}

@test "does not overwrite a file in the way of a future symlink when --force given but also --dry-run" {
  touch src/foo
  touch $DOTFILES_HOME/.foo

  run bin/manage install --force --dry-run
  assert_success

  refute [ -L "$DOTFILES_HOME/.foo" ]
}

@test "does not overwrite a directory that is the way of a future .no-recurse directory symlink" {
  mkdir -p src/foo
  touch src/foo/.no-recurse
  mkdir $DOTFILES_HOME/.foo

  run bin/manage install
  assert_success

  refute [ -L "$DOTFILES_HOME/.foo" ]
}

@test "overwrites a directory that is the way of a future .no-recurse directory symlink when --force given" {
  mkdir -p src/foo
  touch src/foo/.no-recurse
  mkdir $DOTFILES_HOME/.foo

  run bin/manage install --force
  assert_success

  assert [ -L "$DOTFILES_HOME/.foo" ]
  assert_equal "$(readlink "$DOTFILES_HOME/.foo")" "$DOTFILES/src/foo"
}

@test "does not overwrite a directory that is in the way of a future .no-recurse directory symlink when --force given but also --dry run" {
  mkdir -p src/foo
  touch src/foo/.no-recurse
  mkdir $DOTFILES_HOME/.foo

  run bin/manage install --force --dry-run
  assert_success

  refute [ -L "$DOTFILES_HOME/.foo" ]
}

@test "copies a file ending in ._no-link (minus the suffix)" {
  touch src/foo._no-link

  run bin/manage install
  assert_success

  assert [ -f "$DOTFILES_HOME/.foo" ]
  refute [ -L "$DOTFILES_HOME/.foo" ]
}

@test "does not copy a file ending in ._no-link when --dry-run given" {
  touch src/foo._no-link

  run bin/manage install --dry-run
  assert_success

  refute [ -f "$DOTFILES_HOME/.foo" ]
}

@test "does not overwrite a file that is in the way of a ._no-link file" {
  touch src/foo._no-link
  echo hello > $DOTFILES_HOME/.foo

  run bin/manage install
  assert_success

  assert [ -f "$DOTFILES_HOME/.foo" ]
  assert_equal hello "$(< $DOTFILES_HOME/.foo)"
}

@test "overwrites a file that is in the way of a ._no-link file when --force given" {
  touch src/foo._no-link
  echo hello > $DOTFILES_HOME/.foo

  run bin/manage install --force
  assert_success

  assert [ -f "$DOTFILES_HOME/.foo" ]
  assert_equal "" "$(< $DOTFILES_HOME/.foo)"
}

@test "does not overwrite a file that is in the way of a .no-link file when --force given but also --dry-run" {
  touch src/foo._no-link
  echo hello > $DOTFILES_HOME/.foo

  run bin/manage install --force --dry-run
  assert_success

  assert_equal "hello" "$(< $DOTFILES_HOME/.foo)"
}
