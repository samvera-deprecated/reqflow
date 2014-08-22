$:.push(File.join(File.dirname(__FILE__),'..','lib'))
require 'rspec'
require 'fakeredis/rspec'
require 'simplecov'
SimpleCov.start { add_filter 'spec/impl' }
require 'reqflow'


RSpec.configure do |config|
end
