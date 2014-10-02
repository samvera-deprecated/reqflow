require 'rubygems'
require 'bundler'
require "bundler/gem_tasks"
require 'rake/tasklib'
require 'resque/tasks'

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

namespace :reqflow do
  desc "Load bare-bones reqflow for test/experimental purposes"
  task :environment do
    require 'reqflow'
    if ENV['REQFLOW_ROOT']
      Reqflow.root = ENV['REQFLOW_ROOT']
    end
    $stderr.puts "Loaded Reqflow at #{Reqflow.root}"
  end

  desc "Load the reqflow spec environment and workflows"
  task :spec_environment do
    require 'reqflow'
    Reqflow.root = File.expand_path('../spec',__FILE__)
    require File.join(Reqflow.root,'impl','spec_workflow.rb')
  end
end
