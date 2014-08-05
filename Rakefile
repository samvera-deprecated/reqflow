require 'rubygems'
require 'bundler'
require "bundler/gem_tasks"
require 'rake/tasklib'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new do |t|
  t.pattern = FileList['./spec/**/*_spec.rb']
end
  
task :default => :spec
