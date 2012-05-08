$: << File.join(File.dirname(__FILE__), "/../../lib")

if ENV['COVERAGE'] and RUBY_VERSION =~ /^1.9/
  require 'simplecov'
  #require 'simplecov-rcov'

  #SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
  SimpleCov.start
end

require 'spec/autorun'
# require 'spec/rails'
require 'jettywrapper'

Spec::Runner.configure do |config|
  config.mock_with :mocha
end

unless ENV.select { |x| x =~ /TEST_JETTY_PORT/ }.empty?
  TEST_JETTY_PORTS = ENV.select { |x| x =~ /TEST_JETTY_PORT/ }.sort_by { |k,v| k }.map { |k,v| v }
else
  TEST_JETTY_PORTS = [8983, 8984,9999,8888]
end
