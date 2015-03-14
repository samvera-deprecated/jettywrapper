require 'simplecov'
SimpleCov.start

require 'rspec/its'
require 'jettywrapper'

RSpec.configure do |config|
end

unless ENV.select { |k,v| k =~ /TEST_JETTY_PORT/ }.empty?
  TEST_JETTY_PORTS = ENV.select { |k,v| k =~ /TEST_JETTY_PORT/ }.sort_by { |k,v| k }.map { |k,v| v }
else
  TEST_JETTY_PORTS = [8983, 8984,9999,8888]
end
