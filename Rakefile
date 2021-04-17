require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :build do
  require_relative "bin/build"
  Build.call(outfile: Pathname.new("exe/manage").expand_path(__dir__))
  puts "Built to exe/manage."
end

task default: :spec
