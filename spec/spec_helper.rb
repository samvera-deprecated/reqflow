$:.push(File.join(File.dirname(__FILE__),'..','lib'))
require 'rspec'
require 'fakeredis/rspec'
require 'simplecov'
SimpleCov.start
require 'reqflow'


RSpec.configure do |config|
end
