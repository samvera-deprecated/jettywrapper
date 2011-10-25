# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "jettywrapper/version"
require 'bundler'

Gem::Specification.new do |s|
  s.name        = "jettywrapper"
  s.version     = GEMVERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bess Sadler"]
  s.email       = ["bess@stanford.edu"]
  s.homepage    = "https://github.com/projecthydra/jettywrapper"
  s.summary     = %q{Convenience tasks for working with jetty from within a ruby project.}
  s.description = %q{Spin up a jetty instance (e.g., the one at https://github.com/projecthydra/hydra-jetty) and wrap test in it. This lets us run tests against a real copy of solr and fedora.}
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")
  # s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.required_rubygems_version = ">= 1.3.6"
  
  s.add_dependency "logger"
  s.add_dependency "mediashelf-loggable"
  s.add_dependency "childprocess"
  s.add_dependency "i18n"
  s.add_dependency "activesupport", ">=3.0.0"
  
  # Bundler will install these gems too if you've checked this out from source from git and run 'bundle install'
  # It will not add these as dependencies if you require lyber-core for other projects
  s.add_development_dependency "rspec", "< 2.0" # We're not ready to upgrade to rspec 2
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'rcov'
  
  s.add_development_dependency 'yard', '0.6.5'  # Yard > 0.6.5 won't generate docs.
                                                # I don't know why & don't have time to 
                                                # debug it right now
  
  s.add_development_dependency 'RedCloth'
  
end

