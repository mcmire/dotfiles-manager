#!/usr/bin/env ./test/libs/bats-core/bin/bats

load "libs/bats-support/load"
load "libs/bats-assert/load"

absolute-path-of() {
  echo $(cd "$(dirname "$1")" &>/dev/null && pwd)/$(basename "$1")
}

DOTFILES=$(absolute-path-of tmp/dotfiles)
SOURCE_DIR="$DOTFILES/src"
export DOTFILES_HOME=$(absolute-path-of tmp/dotfiles-home)
CUSTOM_DESTINATION=$(absolute-path-of tmp/custom-destination)

scripts/build.sh &>/dev/null

setup() {
  rm -rf "$DOTFILES_HOME"
  mkdir -p "$DOTFILES_HOME"

  rm -rf "$DOTFILES"
  mkdir -p "$DOTFILES/bin"
  mkdir -p "$DOTFILES/src"
  cp dist/manage "$DOTFILES/bin/manage"
  chmod +x "$DOTFILES/bin/manage"
  cd "$DOTFILES"

  rm -rf "$CUSTOM_DESTINATION"
  mkdir -p "$CUSTOM_DESTINATION"
}

@test "installs files in src/ to symlinks in HOME, adding the dot" {
  touch src/some-file

  run bin/manage install
  assert_success

  assert [ -L "$DOTFILES_HOME/.some-file" ]
  assert_equal "$SOURCE_DIR/some-file" "$(readlink "$DOTFILES_HOME/.some-file")"
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
  assert_equal "$SOURCE_DIR/foo/bar/some-file" "$(readlink "$DOTFILES_HOME/.foo/bar/some-file")"
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
  assert_equal "$SOURCE_DIR/foo" "$(readlink "$DOTFILES_HOME/.foo")"
  assert [ -f "$DOTFILES_HOME/.foo/bar/some-file" ]
}

@test "runs __install__.sh in a directory after processing all files in it but before descending into subdirectories" {
  mkdir -p src/foo/baz
  touch src/foo/bar
  touch src/foo/baz/.no-recurse
  touch src/foo/baz/qux
  cat <<SCRIPT > src/foo/__install__.sh
#!/usr/bin/env bash

echo hello > "$DOTFILES_HOME/.foo/bar"
if [[ -d "$DOTFILES_HOME/.foo/baz" ]]; then
  echo hello > "$DOTFILES_HOME/.foo/baz/qux"
fi
SCRIPT
  chmod +x src/foo/__install__.sh

  run bin/manage install
  assert_success

  assert_equal hello "$(< "$DOTFILES_HOME/.foo/bar")"
  assert_equal "" "$(< "$DOTFILES_HOME/.foo/baz/qux")"
}

@test "does not run __install__.sh when --dry-run given" {
  cat <<SCRIPT > src/__install__.sh
#!/usr/bin/env bash

echo hello > "$DOTFILES_HOME/.foo"
SCRIPT
  chmod +x src/__install__.sh

  run bin/manage install --dry-run
  assert_success

  refute [ -e "$DOTFILES_HOME/.foo" ]
}

@test "does not overwrite a file that is in the way of a would-be file symlink" {
  touch src/foo
  touch "$DOTFILES_HOME/.foo"

  run bin/manage install
  assert_success

  refute [ -L $DOTFILES_HOME/.foo ]
}

@test "does not overwrite a symlink that is in the way of a would-be file symlink, even if it is dead" {
  touch src/foo
  ln -s /tmp/nowhere "$DOTFILES_HOME/.foo"

  run bin/manage install
  assert_success

  assert_equal "/tmp/nowhere" "$(readlink "$DOTFILES_HOME/.foo")"
}

@test "overwrites a file in the way of a would-be file symlink when --force given" {
  touch src/foo
  touch $DOTFILES_HOME/.foo

  run bin/manage install --force
  assert_success

  assert [ -L "$DOTFILES_HOME/.foo" ]
  assert_equal "$(readlink "$DOTFILES_HOME/.foo")" "$SOURCE_DIR/foo"
}

@test "does not overwrite a file in the way of a would-be file symlink when --force given but also --dry-run" {
  touch src/foo
  touch $DOTFILES_HOME/.foo

  run bin/manage install --force --dry-run
  assert_success

  refute [ -L "$DOTFILES_HOME/.foo" ]
}

@test "does not overwrite a directory that is the way of a would-be .no-recurse directory symlink" {
  mkdir -p src/foo
  touch src/foo/.no-recurse
  mkdir $DOTFILES_HOME/.foo

  run bin/manage install
  assert_success

  refute [ -L "$DOTFILES_HOME/.foo" ]
}

@test "does not overwrite a symlink that is in the way of a would-be .no-recurse directory symlink, even if it is dead" {
  mkdir -p src/foo
  touch src/foo/.no-recurse
  ln -s /tmp/nowhere "$DOTFILES_HOME/.foo"

  run bin/manage install
  assert_success

  assert_equal "/tmp/nowhere" "$(readlink "$DOTFILES_HOME/.foo")"
}

@test "overwrites a directory that is the way of a would-be .no-recurse directory symlink when --force given" {
  mkdir -p src/foo
  touch src/foo/.no-recurse
  mkdir $DOTFILES_HOME/.foo

  run bin/manage install --force
  assert_success

  assert [ -L "$DOTFILES_HOME/.foo" ]
  assert_equal "$(readlink "$DOTFILES_HOME/.foo")" "$SOURCE_DIR/foo"
}

@test "does not overwrite a directory that is in the way of a would-be .no-recurse directory symlink when --force given but also --dry run" {
  mkdir -p src/foo
  touch src/foo/.no-recurse
  mkdir $DOTFILES_HOME/.foo

  run bin/manage install --force --dry-run
  assert_success

  refute [ -L "$DOTFILES_HOME/.foo" ]
}

@test "copies a file ending in .__no-link__ (minus the suffix)" {
  touch src/foo.__no-link__

  run bin/manage install
  assert_success

  assert [ -f "$DOTFILES_HOME/.foo" ]
  refute [ -L "$DOTFILES_HOME/.foo" ]
}

@test "does not copy a file ending in .__no-link__ when --dry-run given" {
  touch src/foo.__no-link__

  run bin/manage install --dry-run
  assert_success

  refute [ -f "$DOTFILES_HOME/.foo" ]
}

@test "does not overwrite a file that is in the way of a .__no-link__ file" {
  touch src/foo.__no-link__
  echo hello > $DOTFILES_HOME/.foo

  run bin/manage install
  assert_success

  assert [ -f "$DOTFILES_HOME/.foo" ]
  assert_equal hello "$(< $DOTFILES_HOME/.foo)"
}

@test "does not overwrite a symlink that is in the way of a __no-link__ file, even if it is dead" {
  touch src/foo.__no-link__
  ln -s /tmp/nowhere "$DOTFILES_HOME/.foo"

  run bin/manage install
  assert_success

  assert_equal "/tmp/nowhere" "$(readlink "$DOTFILES_HOME/.foo")"
}

@test "overwrites a file that is in the way of a .__no-link__ file when --force given" {
  touch src/foo.__no-link__
  echo hello > $DOTFILES_HOME/.foo

  run bin/manage install --force
  assert_success

  assert [ -f "$DOTFILES_HOME/.foo" ]
  assert_equal "" "$(< $DOTFILES_HOME/.foo)"
}

@test "does not overwrite a file that is in the way of a .no-link file when --force given but also --dry-run" {
  touch src/foo.__no-link__
  echo hello > $DOTFILES_HOME/.foo

  run bin/manage install --force --dry-run
  assert_success

  assert_equal "hello" "$(< $DOTFILES_HOME/.foo)"
}

@test "consults a config file to create symlinks in directories outside of the home directory" {
  touch src/foo
  cat <<CONFIG > src/__overrides__.cfg
[symlinks]
foo = $CUSTOM_DESTINATION/bar
CONFIG

  run bin/manage install
  assert_success

  assert [ -L "$CUSTOM_DESTINATION/bar" ]
  assert_equal "$SOURCE_DIR/foo" "$(readlink "$CUSTOM_DESTINATION/bar")"
}

@test "replaces ~ with the value of HOME in the override config file" {
  touch src/foo
  cat <<CONFIG > src/__overrides__.cfg
[symlinks]
foo = $CUSTOM_DESTINATION/~
CONFIG

  HOME=bar run bin/manage install
  assert_success

  assert [ -L "$CUSTOM_DESTINATION/bar" ]
  assert_equal "$SOURCE_DIR/foo" "$(readlink "$CUSTOM_DESTINATION/bar")"
}

@test "can deal with spaces in the source name" {
  touch "src/foo bar"
  cat <<CONFIG > src/__overrides__.cfg
[symlinks]
foo bar = $CUSTOM_DESTINATION/foo
CONFIG

  run bin/manage install
  assert_success

  assert [ -L "$CUSTOM_DESTINATION/foo" ]
  assert_equal "$SOURCE_DIR/foo bar" "$(readlink "$CUSTOM_DESTINATION/foo")"
}

@test "can deal with spaces in the destination name" {
  touch src/foo
  cat <<CONFIG > src/__overrides__.cfg
[symlinks]
foo = $CUSTOM_DESTINATION/foo bar
CONFIG

  run bin/manage install
  assert_success

  assert [ -L "$CUSTOM_DESTINATION/foo bar" ]
  assert_equal "$SOURCE_DIR/foo" "$(readlink "$CUSTOM_DESTINATION/foo bar")"
}

@test "does not create symlinks from a config file when --dry-run given" {
  touch src/foo
  cat <<CONFIG > src/__overrides__.cfg
[symlinks]
foo = $CUSTOM_DESTINATION/bar
CONFIG

  run bin/manage install --dry-run
  assert_success

  refute [ -e "$CUSTOM_DESTINATION/bar" ]
}

@test "does not overwrite a symlink specified by the config file if it already exists" {
  touch src/some-file
  touch "$CUSTOM_DESTINATION/bar"
  cat <<CONFIG > src/__overrides__.cfg
[symlinks]
foo = $CUSTOM_DESTINATION/bar
CONFIG

  run bin/manage install
  assert_success

  refute [ -L "$CUSTOM_DESTINATION/bar" ]
}

@test "does not overwrite a symlink specified by the config file, even if it is dead" {
  touch src/some-file
  ln -s /tmp/nowhere "$CUSTOM_DESTINATION/bar"
  cat <<CONFIG > src/__overrides__.cfg
[symlinks]
foo = $CUSTOM_DESTINATION/bar
CONFIG

  run bin/manage install
  assert_success

  assert_equal "/tmp/nowhere" "$(readlink "$CUSTOM_DESTINATION/bar")"
}

@test "overwrites a symlink specified by the config file if it already exists if --force given" {
  touch src/some-file
  touch "$CUSTOM_DESTINATION/bar"
  cat <<CONFIG > src/__overrides__.cfg
[symlinks]
foo = $CUSTOM_DESTINATION/bar
CONFIG

  run bin/manage install --force
  assert_success

  assert [ -L "$CUSTOM_DESTINATION/bar" ]
  assert_equal "$SOURCE_DIR/foo" "$(readlink "$CUSTOM_DESTINATION/bar")"
}

@test "does not overwrite a symlink specified by the config file if it already exists if --force given but also --dry-run" {
  touch src/some-file
  touch "$CUSTOM_DESTINATION/bar"
  cat <<CONFIG > src/__overrides__.cfg
[symlinks]
foo = $CUSTOM_DESTINATION/bar
CONFIG

  run bin/manage install --force --dry-run
  assert_success

  refute [ -L "$CUSTOM_DESTINATION/bar" ]
}

@test "saves command-level options to a global config file" {
  touch src/some-file

  run bin/manage install --force --foo bar --baz qux
  assert_success

  assert [ -f "$DOTFILES_HOME/.dotfilesrc" ]
  expected_content=$(cat <<'TEXT'
[install]
foo = "bar"
baz = "qux"
TEXT
  )
  assert_equal "$expected_content" "$(cat "$DOTFILES_HOME/.dotfilesrc")"
}

@test "re-uses command-level in the global config file upon subsequent runs" {
  touch src/some-file
  cat <<'TEXT' > $DOTFILES_HOME/.dotfilesrc
[install]
foo = "bar"
baz = "qux"
TEXT

  run bin/manage install
  assert_success

  expected_content=$(cat <<'TEXT'
[install]
foo = "bar"
baz = "qux"
TEXT
  )
  assert_equal "$expected_content" "$(cat "$DOTFILES_HOME/.dotfilesrc")"
}
