#!/usr/bin/env ruby

require "pathname"
require "fileutils"

class TestSandbox
  attr_reader :project_dir, :root_dir, :dotfiles_home, :dotfiles, :source_dir

  def initialize
    @project_dir = Pathname.new("..").expand_path(__dir__)
    @root_dir = project_dir.join("tmp")
    @dotfiles_home = root_dir.join("dotfiles-home")
    @dotfiles = root_dir.join("dotfiles")
    @source_dir = dotfiles.join("src")
  end

  def provision
    root_dir.glob("*").each(&:rmtree)

    dotfiles_home.mkpath
    dotfiles.join("bin").mkpath
    source_dir.mkpath
  end
end

if File.expand_path($0) == File.expand_path(__FILE__)
  TestSandbox.new.provision
end
