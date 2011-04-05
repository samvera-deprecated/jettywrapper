# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hydra-testing/version"
require 'bundler'

Gem::Specification.new do |s|
  s.name        = "hydra-testing"
  s.version     = Hydra::Testing::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bess Sadler"]
  s.email       = ["bess@stanford.edu"]
  s.homepage    = ""
  s.summary     = %q{Convenience tasks and classes for automated testing for the hydra project.}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "hydra-testing"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

# Gem requirements are managed in Gemfile
Gem::Specification.new do |s|
  s.add_bundler_dependencies
end