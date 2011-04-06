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
  s.summary     = %q{Convenience tasks for automated testing for the hydra project.}
  s.description = %q{Spin up a jetty instance (maybe even the one at https://github.com/projecthydra/hydra-jetty) and wrap test in it. This lets us run tests against a real copy of solr and fedora.}

  s.rubyforge_project = "hydra-testing"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.required_rubygems_version = ">= 1.3.6"
  
  # Bundler will install these gems too if you've checked this out from source from git and run 'bundle install'
  # It will not add these as dependencies if you require lyber-core for other projects
  s.add_development_dependency "ruby-debug"
  s.add_development_dependency "ruby-debug-base"
  s.add_development_dependency "rspec", "< 2.0" # We're not ready to upgrade to rspec 2
  s.add_development_dependency 'rspec-rails', '<2.0.0' # rspec-rails 2.0.0 requires Rails 3.
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'cucumber', '>=0.8.5'
  s.add_development_dependency 'cucumber-rails'
  s.add_development_dependency 'gherkin'
  s.add_development_dependency 'rcov'
  s.add_development_dependency 'yard'
  
end

