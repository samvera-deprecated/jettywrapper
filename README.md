# Jettywrapper [![Version](https://badge.fury.io/gh/projecthydra%2Fjettywrapper.png)](http://badge.fury.io/gh/projecthydra%2Fjettywrapper) [![Build Status](https://travis-ci.org/projecthydra/jettywrapper.png?branch=master)](https://travis-ci.org/projecthydra/jettywrapper)

NOTICE:  Because of changes introduced in Solr 5, we can no longer update jettywrapper to use modern versions of Solr. Therefore we discourage you from using jettywrapper in new projects.  No further development is anticipated for jettywrapper. Consider using [solr_wrapper](https://github.com/cbeer/solr_wrapper) and [fcrepo_wrapper](https://github.com/cbeer/fcrepo_wrapper) instead.

This gem is designed to make it easier to integrate a jetty servlet container into a project with web service dependencies.  This can be especially useful for developing and testing projects requiring, for example, a Solr and/or a Fedora server.

Jettywrapper provides rake tasks for starting and stopping jetty, as well as the method `Jettywrapper.wrap` that will start the server before the block and stop the server after the block, which is useful for automated testing.

Jettywrapper can be configured to work with any Jetty-based zip file, such as [blacklight-jetty](https://github.com/projectblacklight/blacklight-jetty) (Solr only) or [hydra-jetty](https://github.com/projecthydra/hydra-jetty) (Solr + Fedora). Jettywrapper uses hydra-jetty by default.

## Requirements

1.  ruby -- Jettywrapper supports the ruby versions in its [.travis.yml](.travis.yml) file.
2.  bundler -- this ruby gem must be installed.
3.  java -- Jetty is a java based servlet container; the version of java required depends on the version of jetty you are using (in the jetty-based zip file).

## Installation

Generally, you will only use a jetty instance for your project's web service dependencies during development and testing, not for production. So you would add this to your Gemfile:

```
group :development, :test do
  gem 'jettywrapper'
end
```

Or, if your project is a gem, you would add this to your .gemspec file:

```
Gem::Specification.new do |s|
  s.add_development_dependency 'jettywrapper'
end
```

Then execute:

    $ bundle

Or install it yourself as:

    $ gem install jettywrapper


## Usage

### Configuration

See [Configuring jettywrapper](https://github.com/projecthydra/jettywrapper/wiki/Configuring-jettywrapper).

If you don't need both Solr and Fedora, we recommend you avoid the default [hydra-jetty](https://github.com/projecthydra/hydra-jetty). If you only need Solr, use [blacklight-jetty](https://github.com/projectblacklight/blacklight-jetty).

### Gotchas

* Jetty may take a while to spin up
* Jetty may not shut down cleanly

See [Using jettywrapper](https://github.com/projecthydra/jettywrapper/wiki/Using-jettywrapper) for more information and what to do.

### Example Rake Task

See [Using jettywrapper](https://github.com/projecthydra/jettywrapper/wiki/Using-jettywrapper) for more information.

```ruby
require 'jettywrapper'

desc 'run the tests for continuous integration'
task ci: ['jetty:clean', 'myproj:configure_jetty'] do
  ENV['environment'] = 'test'
  jetty_params = Jettywrapper.load_config
  jetty_params[:startup_wait] = 60

  error = nil
  error = Jettywrapper.wrap(jetty_params) do
    # run the tests
    Rake::Task['spec'].invoke
  end
  raise "test failures: #{error}" if error
end
```

## Contributing

See [CONTRIBUTING.md](https://github.com/projecthydra/jettywrapper/blob/master/CONTRIBUTING.md) to help us make this project better.
