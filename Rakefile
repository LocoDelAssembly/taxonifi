#!/usr/bin/env rake

require 'bundler/gem_tasks'
require 'rake'
require 'rake/testtask'
require 'taxonifi/version'
require 'taxonifi'

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.warning = false
end

# require 'rcov/rcovtask'
# Rcov::RcovTask.new do |test|
#  test.libs << 'test'
#  test.pattern = 'test/**/test_*.rb'
#  test.verbose = true
#  test.rcov_opts << '--exclude "gems/*"'
# end

task :default => :test


require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
 version = Taxonifi::VERSION 

 rdoc.rdoc_dir = 'rdoc'
 rdoc.title = "taxonifi #{version}"
 rdoc.rdoc_files.include('README*')
 rdoc.rdoc_files.include('lib/**/*.rb')

end
