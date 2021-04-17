require "fileutils"

RSpec.describe "exe/manage install" do
  it "installs files in src/ to symlinks in HOME, adding the dot" do
    FileUtils.touch(source_dir.join("some-file"))

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/some-file --> ~/.some-file"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".some-file")).to be_a_symlink_to(
      source_dir.join("some-file")
    )
  end

  it "does not install symlinks for files directly in src/ when --dry-run given" do
    FileUtils.touch(source_dir.join("some-file"))

    command = run!("bin/manage install --dry-run")

    expect(command).to(
      have_output do |d|
        d.bold_line "Running in dry-run mode."
        d.newline
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/some-file --> ~/.some-file"
        end
        d.newline
        d.bold_line "Don't worry — no files were created!"
      end
    )
    expect(dotfiles_home.join(".some-file")).not_to exist
  end

  it "descends into subdirectories in src/ by default and symlinks files inside, adding the dot to the top-level directory" do
    source_dir.join("foo/bar").mkpath
    FileUtils.touch(source_dir.join("foo/bar/some-file"))

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo/bar/some-file --> ~/.foo/bar/some-file"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo/bar/some-file")).to be_a_symlink_to(
      source_dir.join("foo/bar/some-file")
    )
  end

  it "does not install symlinks for files deep in src/ when --dry-run given" do
    source_dir.join("foo/bar").mkpath
    FileUtils.touch(source_dir.join("foo/bar/some-file"))

    command = run!("bin/manage install --dry-run")

    expect(command).to(
      have_output do |d|
        d.bold_line "Running in dry-run mode."
        d.newline
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo/bar/some-file --> ~/.foo/bar/some-file"
        end
        d.newline
        d.bold_line "Don't worry — no files were created!"
      end
    )
    expect(dotfiles_home.join(".foo/bar/some-file")).not_to exist
  end

  it "does not descend into subdirectories that have a .no-recurse file present, instead symlinking the whole directory" do
    source_dir.join("foo/bar").mkpath
    FileUtils.touch(source_dir.join("foo/.no-recurse"))
    FileUtils.touch(source_dir.join("foo/bar/some-file"))

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo/ --> ~/.foo/"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).to be_a_symlink_to(
      source_dir.join("foo")
    )
    expect(dotfiles_home.join(".foo/bar/some-file")).to exist
  end

  it "runs __install__.sh in its directory, exposing the values passed to the install command, after processing all files in it but before descending into subdirectories" do
    source_dir.join("foo/baz").mkpath
    FileUtils.touch(source_dir.join("foo/bar"))
    FileUtils.touch(source_dir.join("foo/baz/.no-recurse"))
    FileUtils.touch(source_dir.join("foo/baz/qux"))
    source_dir.join("foo/__install__.sh").write(<<~SCRIPT)
      #!/usr/bin/env bash

      echo "\$SOME_VARIABLE \$ANOTHER_VARIABLE" > "#{dotfiles_home.join(".foo/bar")}"
      if [[ -d "#{dotfiles_home}/.foo/baz" ]]; then
        echo hello > "#{dotfiles_home.join(".foo/baz/qux")}"
      fi
    SCRIPT
    source_dir.join("foo/__install__.sh").chmod(0777)

    command =
      run!(
        "bin/manage install --some-variable value1 --another-variable value2"
      )

    # TODO: Is this output correct?
    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo/bar --> ~/.foo/bar"
        end
        d.line do |l|
          l._green "     run"
          l._plain " "
          l.yellow " command"
          l._plain " $DOTFILES/src/foo/__install__.sh"
        end
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo/baz/ --> ~/.foo/baz/"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo/bar").read).to eq("value1 value2\n")
    expect(dotfiles_home.join(".foo/baz/qux").read).to eq("")
  end

  it "does not run __install__.sh when --dry-run given" do
    source_dir.join("__install__.sh").write(<<~SCRIPT)
      #!/usr/bin/env bash

      echo hello > "#{dotfiles_home}/.foo"
    SCRIPT
    source_dir.join("__install__.sh").chmod(0777)

    command = run!("bin/manage install --dry-run")

    expect(command).to(
      have_output do |d|
        d.bold_line "Running in dry-run mode."
        d.newline
        d.line do |l|
          l._green "     run"
          l._plain " "
          l.yellow " command"
          l._plain " $DOTFILES/src/__install__.sh"
        end
        d.newline
        d.bold_line "Don't worry — no files were created!"
      end
    )
    expect(dotfiles_home.join(".foo")).not_to exist
  end

  it "does not overwrite a file that is in the way of a would-be file symlink" do
    FileUtils.touch(source_dir.join("foo"))
    FileUtils.touch(dotfiles_home.join(".foo"))

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l.__blue "  exists"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/.foo"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).not_to be_a_symlink
  end

  it "does not overwrite a symlink that is in the way of a would-be file symlink, even if it is dead" do
    FileUtils.touch(source_dir.join("foo"))
    Pathname.new(dotfiles_home.join(".foo")).make_symlink("/tmp/nowhere")

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l.__blue "  exists"
          l._plain " "
          l.yellow "    link"

          # TODO: Doesn't this link go somewhere else?
          l._plain " $DOTFILES/src/foo --> ~/.foo"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).to be_a_symlink_to("/tmp/nowhere")
  end

  it "overwrites a file that is in the way of a would-be file symlink when --force given" do
    FileUtils.touch(source_dir.join("foo"))
    FileUtils.touch(dotfiles_home.join(".foo"))

    command = run!("bin/manage install --force")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l.___red "overwrite"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/.foo"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).to be_a_symlink_to(
      source_dir.join("foo")
    )
  end

  it "does not overwrite a file in the way of a would-be file symlink when --force given but also --dry-run" do
    FileUtils.touch(source_dir.join("foo"))
    FileUtils.touch(dotfiles_home.join(".foo"))

    command = run!("bin/manage install --force --dry-run")

    expect(command).to(
      have_output do |d|
        d.bold_line "Running in dry-run mode."
        d.newline
        d.line do |l|
          l.___red "overwrite"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/.foo"
        end
        d.newline
        d.bold_line "Don't worry — no files were created!"
      end
    )
    expect(dotfiles_home.join(".foo")).not_to be_a_symlink
  end

  it "does not overwrite a directory that is the way of a would-be .no-recurse directory symlink" do
    source_dir.join("foo").mkpath
    FileUtils.touch(source_dir.join("foo/.no-recurse"))
    dotfiles_home.join(".foo").mkdir

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l.__blue "  exists"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo/ --> ~/.foo/"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).not_to be_a_symlink
  end

  it "does not overwrite a symlink that is in the way of a would-be .no-recurse directory symlink, even if it is dead" do
    source_dir.join("foo").mkpath
    FileUtils.touch(source_dir.join("foo/.no-recurse"))
    dotfiles_home.join(".foo").make_symlink("/tmp/nowhere")

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l.__blue "  exists"
          l._plain " "
          l.yellow "    link"

          # TODO: Doesn't this link go somewhere else?
          l._plain " $DOTFILES/src/foo/ --> ~/.foo/"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).to be_a_symlink_to("/tmp/nowhere")
  end

  it "overwrites a directory that is the way of a would-be .no-recurse directory symlink when --force given" do
    source_dir.join("foo").mkpath
    FileUtils.touch(source_dir.join("foo/.no-recurse"))
    dotfiles_home.join(".foo").mkdir

    command = run!("bin/manage install --force")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l.___red "overwrite"
          l._plain " "
          l.yellow "    link"

          l._plain " $DOTFILES/src/foo/ --> ~/.foo/"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).to be_a_symlink_to(
      source_dir.join("foo")
    )
  end

  it "does not overwrite a directory that is in the way of a would-be .no-recurse directory symlink when --force given but also --dry-run" do
    source_dir.join("foo").mkpath
    FileUtils.touch(source_dir.join("foo/.no-recurse"))
    dotfiles_home.join(".foo").mkdir

    command = run!("bin/manage install --force --dry-run")

    expect(command).to(
      have_output do |d|
        d.bold_line "Running in dry-run mode."
        d.newline
        d.line do |l|
          l.___red "overwrite"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo/ --> ~/.foo/"
        end
        d.newline
        d.bold_line "Don't worry — no files were created!"
      end
    )
    expect(dotfiles_home.join(".foo")).not_to be_a_symlink
  end

  it "copies a file ending in .__no-link__ (minus the suffix)" do
    source_dir.join("foo.__no-link__").write("some content")

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "non_link"
          l._plain " $DOTFILES/src/foo.__no-link__ --> ~/.foo"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).not_to be_a_symlink
    expect(dotfiles_home.join(".foo")).to be_same_file_as(
      source_dir.join("foo.__no-link__")
    )
  end

  it "does not copy a file ending in .__no-link__ when --dry-run given" do
    source_dir.join("foo.__no-link__").write("some content")

    command = run!("bin/manage install --dry-run")

    expect(command).to(
      have_output do |d|
        d.bold_line "Running in dry-run mode."
        d.newline
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "non_link"
          l._plain " $DOTFILES/src/foo.__no-link__ --> ~/.foo"
        end
        d.newline
        d.bold_line "Don't worry — no files were created!"
      end
    )
    expect(dotfiles_home.join(".foo")).not_to exist
  end

  it "does not overwrite a file that is in the way of a .__no-link__ file" do
    source_dir.join("foo.__no-link__").write("hello")
    dotfiles_home.join(".foo").write("goodbye")

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l.__blue "  exists"
          l._plain " "
          l.yellow "   entry"
          l._plain " $DOTFILES/src/foo.__no-link__ --> ~/.foo"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).to exist
    expect(dotfiles_home.join(".foo").read).to eq("goodbye")
  end

  it "does not overwrite a symlink that is in the way of a __no-link__ file, even if it is dead" do
    FileUtils.touch(source_dir.join("foo.__no-link__"))
    dotfiles_home.join(".foo").make_symlink("/tmp/nowhere")

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l.__blue "  exists"
          l._plain " "
          l.yellow "   entry"
          l._plain " $DOTFILES/src/foo.__no-link__ --> ~/.foo"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).to be_a_symlink_to("/tmp/nowhere")
  end

  it "overwrites a file that is in the way of a .__no-link__ file when --force given" do
    source_dir.join("foo.__no-link__").write("hello")
    dotfiles_home.join(".foo").write("goodbye")

    command = run!("bin/manage install --force")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l.___red "overwrite"
          l._plain " "
          l.yellow "non_link"
          l._plain " $DOTFILES/src/foo.__no-link__ --> ~/.foo"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join(".foo")).to exist
    expect(dotfiles_home.join(".foo").read).to eq("hello")
  end

  it "does not overwrite a file that is in the way of a .no-link file when --force given but also --dry-run" do
    source_dir.join("foo.__no-link__").write("hello")
    dotfiles_home.join(".foo").write("goodbye")

    command = run!("bin/manage install --force --dry-run")

    expect(command).to(
      have_output do |d|
        d.bold_line "Running in dry-run mode."
        d.newline
        d.line do |l|
          l.___red "overwrite"
          l._plain " "
          l.yellow "non_link"
          l._plain " $DOTFILES/src/foo.__no-link__ --> ~/.foo"
        end
        d.newline
        d.bold_line "Don't worry — no files were created!"
      end
    )
    expect(dotfiles_home.join(".foo").read).to eq("goodbye")
  end

  it "consults a config file to create symlinks in directories outside of the home directory" do
    dir_outside_dotfiles = sandbox_dir.join("outside")
    dir_outside_dotfiles.mkpath
    FileUtils.touch(source_dir.join("foo"))
    source_dir.join("__overrides__.cfg").write(<<~CONFIG)
      {
        "symlinks": {
          "foo": "#{dir_outside_dotfiles.join("bar")}"
        }
      }
    CONFIG

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "    read"
          l._plain " "
          l.yellow "  config"
          l._plain " $DOTFILES/src/__overrides__.cfg"
        end
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/../outside/bar"
        end

        # FIXME: This shouldn't be here
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/.foo"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dir_outside_dotfiles.join("bar")).to be_a_symlink_to(
      source_dir.join("foo")
    )
  end

  it "replaces ~ with the value of HOME in the override config file" do
    FileUtils.touch(source_dir.join("foo"))
    source_dir.join("__overrides__.cfg").write(<<~CONFIG)
      {
        "symlinks": {
          "foo": "~/bar"
        }
      }
    CONFIG

    command = run!("bin/manage install", env: { "HOME" => dotfiles_home.to_s })

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "    read"
          l._plain " "
          l.yellow "  config"
          l._plain " $DOTFILES/src/__overrides__.cfg"
        end
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/bar"
        end

        # FIXME: This shouldn't be here
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/.foo"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dotfiles_home.join("bar")).to be_a_symlink_to(source_dir.join("foo"))
  end

  it "can deal with spaces in the source name" do
    dir_outside_dotfiles = sandbox_dir.join("outside")
    dir_outside_dotfiles.mkpath
    FileUtils.touch(source_dir.join("foo bar"))
    source_dir.join("__overrides__.cfg").write(<<~CONFIG)
      {
        "symlinks": {
          "foo bar": "#{dir_outside_dotfiles.join("foo")}"
        }
      }
    CONFIG

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "    read"
          l._plain " "
          l.yellow "  config"
          l._plain " $DOTFILES/src/__overrides__.cfg"
        end
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo bar --> ~/../outside/foo"
        end

        # FIXME: This shouldn't be here
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo bar --> ~/.foo bar"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dir_outside_dotfiles.join("foo")).to be_a_symlink_to(
      source_dir.join("foo bar")
    )
  end

  it "can deal with spaces in the destination name" do
    dir_outside_dotfiles = sandbox_dir.join("outside")
    dir_outside_dotfiles.mkpath
    FileUtils.touch(source_dir.join("foo"))
    source_dir.join("__overrides__.cfg").write(<<~CONFIG)
      {
        "symlinks": {
          "foo": "#{dir_outside_dotfiles.join("foo bar")}"
        }
      }
    CONFIG

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "    read"
          l._plain " "
          l.yellow "  config"
          l._plain " $DOTFILES/src/__overrides__.cfg"
        end
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/../outside/foo bar"
        end

        # FIXME: This shouldn't be here
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/.foo"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dir_outside_dotfiles.join("foo bar")).to be_a_symlink_to(
      source_dir.join("foo")
    )
  end

  it "does not create symlinks from a config file when --dry-run given" do
    dir_outside_dotfiles = sandbox_dir.join("outside")
    dir_outside_dotfiles.mkpath
    FileUtils.touch(source_dir.join("foo"))
    source_dir.join("__overrides__.cfg").write(<<~CONFIG)
      {
        "symlinks": {
          "foo": "#{dir_outside_dotfiles.join("bar")}"
        }
      }
    CONFIG

    command = run!("bin/manage install --dry-run")

    expect(command).to(
      have_output do |d|
        d.bold_line "Running in dry-run mode."
        d.newline
        d.line do |l|
          l._green "    read"
          l._plain " "
          l.yellow "  config"
          l._plain " $DOTFILES/src/__overrides__.cfg"
        end
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/../outside/bar"
        end

        # FIXME: This shouldn't be here
        d.line do |l|
          l._green "  create"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/.foo"
        end
        d.newline
        d.bold_line "Don't worry — no files were created!"
      end
    )
    expect(dir_outside_dotfiles.join("bar")).not_to be_a_symlink
  end

  it "does not overwrite a symlink specified by the config file if it already exists" do
    dir_outside_dotfiles = sandbox_dir.join("outside")
    dir_outside_dotfiles.mkpath
    FileUtils.touch(dir_outside_dotfiles.join("bar"))
    source_dir.join("__overrides__.cfg").write(<<~CONFIG)
      {
        "symlinks": {
          "foo": "#{dir_outside_dotfiles.join("bar")}"
        }
      }
    CONFIG

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "    read"
          l._plain " "
          l.yellow "  config"
          l._plain " $DOTFILES/src/__overrides__.cfg"
        end
        d.line do |l|
          l.__blue "  exists"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/../outside/bar"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dir_outside_dotfiles.join("bar")).not_to be_a_symlink
  end

  it "does not overwrite a symlink specified by the config file, even if it is dead" do
    dir_outside_dotfiles = sandbox_dir.join("outside")
    dir_outside_dotfiles.mkpath
    dir_outside_dotfiles.join("bar").make_symlink("/tmp/nowhere")
    source_dir.join("__overrides__.cfg").write(<<~CONFIG)
      {
        "symlinks": {
          "foo": "#{dir_outside_dotfiles.join("bar")}"
        }
      }
    CONFIG

    command = run!("bin/manage install")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "    read"
          l._plain " "
          l.yellow "  config"
          l._plain " $DOTFILES/src/__overrides__.cfg"
        end
        d.line do |l|
          l.__blue "  exists"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/../outside/bar"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dir_outside_dotfiles.join("bar")).to be_a_symlink_to("/tmp/nowhere")
  end

  it "overwrites a symlink specified by the config file if it already exists if --force given" do
    dir_outside_dotfiles = sandbox_dir.join("outside")
    dir_outside_dotfiles.mkpath
    FileUtils.touch(dir_outside_dotfiles.join("bar"))
    source_dir.join("__overrides__.cfg").write(<<~CONFIG)
      {
        "symlinks": {
          "foo": "#{dir_outside_dotfiles.join("bar")}"
        }
      }
    CONFIG

    command = run!("bin/manage install --force")

    expect(command).to(
      have_output do |d|
        d.line do |l|
          l._green "    read"
          l._plain " "
          l.yellow "  config"
          l._plain " $DOTFILES/src/__overrides__.cfg"
        end
        d.line do |l|
          l.___red "overwrite"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/../outside/bar"
        end
        d.newline
        d.green_line "All files are installed, you're good!"
        d.plain_line "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    )
    expect(dir_outside_dotfiles.join("bar")).to be_a_symlink_to(
      source_dir.join("foo")
    )
  end

  it "does not overwrite a symlink specified by the config file if it already exists if --force given but also --dry-run" do
    dir_outside_dotfiles = sandbox_dir.join("outside")
    dir_outside_dotfiles.mkpath
    FileUtils.touch(dir_outside_dotfiles.join("bar"))
    source_dir.join("__overrides__.cfg").write(<<~CONFIG)
      {
        "symlinks": {
          "foo": "#{dir_outside_dotfiles.join("bar")}"
        }
      }
    CONFIG

    command = run!("bin/manage install --force --dry-run")

    expect(command).to(
      have_output do |d|
        d.bold_line "Running in dry-run mode."
        d.newline
        d.line do |l|
          l._green "    read"
          l._plain " "
          l.yellow "  config"
          l._plain " $DOTFILES/src/__overrides__.cfg"
        end
        d.line do |l|
          l.___red "overwrite"
          l._plain " "
          l.yellow "    link"
          l._plain " $DOTFILES/src/foo --> ~/../outside/bar"
        end
        d.newline
        d.bold_line "Don't worry — no files were created!"
      end
    )
    expect(dir_outside_dotfiles.join("bar")).not_to be_a_symlink
  end

  it "saves command-level options to a global config file" do
    run!("bin/manage install --force --foo bar --baz qux")

    expect(dotfiles_home.join(".dotfilesrc")).to exist
    expect(dotfiles_home.join(".dotfilesrc").read).to eq(<<~TEXT.rstrip)
      {
        "install": {
          "foo": "bar",
          "baz": "qux"
        },
        "uninstall": {
        }
      }
    TEXT
  end

  it "re-uses command-level options in the global config file upon subsequent runs" do
    dotfiles_home.join(".dotfilesrc").write(<<~TEXT)
      {
        "install": {
          "foo": "bar",
          "baz": "qux"
        }
      }
    TEXT
    source_dir.join("__install__.sh").write(<<~SCRIPT)
      #!/usr/bin/env bash

      echo "\$FOO \$BAZ" > "#{dotfiles_home.join("foo")}"
    SCRIPT
    source_dir.join("__install__.sh").chmod(0777)

    run!("bin/manage install")

    expect(dotfiles_home.join("foo").read).to eq("bar qux\n")
    expect(dotfiles_home.join(".dotfilesrc")).to exist
    expect(dotfiles_home.join(".dotfilesrc").read).to eq(<<~TEXT.rstrip)
      {
        "install": {
          "foo": "bar",
          "baz": "qux"
        },
        "uninstall": {
        }
      }
    TEXT
  end

  it "converts dashes in command-line options to underscores when persisting the global config file" do
    run!("bin/manage install --force --foo-bar 1 --baz-bar 2")

    expect(dotfiles_home.join(".dotfilesrc")).to exist
    expect(dotfiles_home.join(".dotfilesrc").read).to eq(<<~TEXT.rstrip)
      {
        "install": {
          "foo_bar": "1",
          "baz_bar": "2"
        },
        "uninstall": {
        }
      }
    TEXT
  end

  it "can handle options with underscores in the global config file when running a custom install script" do
    dotfiles_home.join(".dotfilesrc").write(<<~TEXT)
      {
        "install": {
          "foo_bar": "1",
          "baz_bar": "2"
        }
      }
    TEXT
    source_dir.join("__install__.sh").write(<<~SCRIPT)
      #!/usr/bin/env bash

      echo "\$FOO_BAR \$BAZ_BAR" > "#{dotfiles_home.join("foo")}"
    SCRIPT
    source_dir.join("__install__.sh").chmod(0777)

    run!("bin/manage install")

    expect(dotfiles_home.join("foo").read).to eq("1 2\n")
  end
end
