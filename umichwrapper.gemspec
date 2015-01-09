# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "umichwrapper/version"
require 'bundler'

Gem::Specification.new do |s|
  s.name        = "umichwrapper"
  s.version     = UMichwrapper::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Chris Beer", "Justin Coyne", "Bess Sadler", "Colin Gross"]
  s.email       = ["grosscol@umich.edu"]
  s.homepage    = "https://github.com/grosscol/umichwrapper"
  s.summary     = %q{Convenience tasks for working with U of M library environment from within a ruby project.}
  s.description = %q{Deploy to UM Lib app instance and test configuration.  Runs tests against U of M dev copy of solr and fedora.}
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")
  s.require_paths = ["lib"]
  s.license       = 'APACHE2'
  
  s.required_rubygems_version = ">= 1.3.6"
  
  s.add_dependency "logger"
  s.add_dependency "childprocess"
  s.add_dependency "i18n"
  s.add_dependency "activesupport", ">=3.0.0"
  
  s.add_development_dependency "rspec", '~> 2.99'
  s.add_development_dependency "rspec-its"
  s.add_development_dependency 'rake'
  
  s.add_development_dependency 'yard'
end

