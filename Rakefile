require File.expand_path('../lib/tools/update_version', __FILE__)
require "bundler/gem_tasks"

# Spec
require 'rake/testtask'
Rake::TestTask.new(:spec) do |spec|
	spec.libs << "spec"
	spec.test_files = Dir['spec/**/*_spec.rb']
	spec.verbose = true
end


task :default => :spec
