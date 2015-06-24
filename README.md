# UMichwrapper

This gem is a poorly done hack of Jettwrapper.  It is designed as a replacement for Jettywrapper in the shared dev environment at the Univerisity of Michigan Library.  This provides the setup tasks for getting a developer solr core and fedora node running on the shared infrastructure.  It does not provide the convenient start/stop functionality that Jettywrapper provides to automate testing.

## Use

Create a new rails project `rails new --skip-bundle myproject`

Change directory into your new project `cd myproject`

Adding the UMichwrapper github repo to your rails project's Gemfile and using bundle install should make the umich tasks available to rake:
```
# UMichwrapper
gem 'umichwrapper', github: 'mlibrary/umichwrapper', branch: 'master'
``` 
Run bundle install `bundle install --path=.bundle`

Verify umich tasks are available with `bundle exec rake --tasks`

Test the test the status task with `bundle exec rake umich:status`

Use `bundle exec rake umich:setup` prior to running your rails server.

## Configuring

**Make sure that your project's config directory (config/*) is included in .gitignore:** 

Good practice, common sense, and decency to sysadmins all suggest that you omit your local configuration from your git repository.

UMichwrapper starts by looking for fedora.yml, solr.yml, and umich.yml in your project's config directory.  Failing that, it uses the umich.yml in the gem's config directory.  The defaults are set up to work in the UMich dev deoployment. 

## Notes

 * The unit and integration tests have yet to be completed. 
 * This gem does not yet support facilitating testing in the same way that jettywrapper does.

## Dive into Hydra idiosyncracies

 * In order to start a dive-into-hydra project:
    1. `mkdir <project_name>`
    1. `cd <project_name>`
    1. `bundle init`
    1. `echo "gem 'rails', '~> 4.2'" >> Gemfile`
    1. `bundle install`
    1. `bundle exec rails new . -f`
    1. Make the additions to the Gemfile (see below for copy/pastable)
      * add hydra dependency.
      * add umichwrapper depenency.
      * add preemptive dependencies to work around a bundler related issue.
    1. `bundle install`
    1. `rails generate hydra:install` 
    1. Configure solr.yml and fedora.yml.  The default values won't work.

 * Additions to your project's gemfile:
```
# Primary Hydra Dependency
gem 'hydra', '9.0.0'

# UMichwrapper
gem 'umichwrapper', github: 'mlibrary/umichwrapper', branch: 'master'

# Preemptively require gems so that rails generate hydra:install will complete.
#   This is a vendorized gems issue with Bundle.with_clean_env
gem 'orm_adapter'
gem 'responders'
gem 'warden'
gem 'devise'
gem 'devise-guests', '~> 0.3'
gem 'bcrypt'
gem 'thread_safe'
```

fedora.yml
```
development:
  url: http://localhost:8080/fedora/rest
  base_path: /uniquename-dev
```
solr.yml
```
# This is a sample config file that points to a solr core
development:
  url: http://localhost:8080/tomcat/quod-dev/solr-hydra/uniquename-dev
```

 * Errors during rails generate about "Could not find gem 'bundler'" can be ignored so long as you have already installed the gems that the call to bundle install from the generator would have installed.  It appears that this is a result of Bundle.with_clean_env being called from within a second tier Bundle environment (ENV -> Bundle -> Bundle).


