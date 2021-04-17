require "pathname"

module DotfilesManager
  class << self
    attr_accessor :dotfiles_home
  end

  def self.project_dir
    @project_dir ||=
      begin
        path = Pathname.new(__dir__)
        if %w[bin exe].include?(path.basename.to_s)
          path.parent
        else
          path.parent.parent
        end
      end
  end

  def self.source_dir
    project_dir.join("src")
  end

  def self.config_file_path
    dotfiles_home.join(".dotfilesrc")
  end

  self.dotfiles_home =
    Pathname.new(ENV["DOTFILES_HOME"] || ENV["HOME"]).expand_path(Dir.pwd)
end
