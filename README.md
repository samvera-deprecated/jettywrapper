# UMichwrapper

This gem is a poorly done hack of Jettwrapper.  It is designed as a replacement for Jettywrapper in the shared dev environment at the Univerisity of Michigan Library.  This provides the start, stop, and clean tasks for deploying rails applications to our stack.  It does not provide the convenient start/stop functionality that Jettywrapper provides to automate testing.


## Configuring

UMichwrapper starts by looking for config/umich.yml in your project.  Failing that, it uses the umich.yml in the gem's config directory.  Finally, there are some defaults in the code for parameters that require values.  The defaults are set up to work in the UMich dev deoployment of solr, fedora, and torquebox. 

```yaml
development:
  startup_wait: 59
  solr_host: localhost
  solr_port: 8080
  solr_home: /quod-dev/idx/h/hydra-solr
  solr_cntx: hydra-solr

testing:
  startup_wait: 29
  solr_home: /quod-dev/idx/h/hydra-solr
  solr_cntx: hydra-solr
```

## Use

Adding the UMichwrapper github repo to your rails project's Gemfile and using bundle install should make the umich tasks available to rake.

```
# UMichwrapper
gem 'umichwrapper', github: 'grosscol/umichwrapper', branch: 'master'
``` 
Verify umich tasks are available with `bundle exec rake --tasks`

## Notes

 * This gem does not yet read from solr.yml and fedora.yml in your project config.  However, those do need to point to the corresponding solr and fedora instance/context.  Currently keeping these both configured is on the developer.  Having the UMichwrapper read the solr and fedora configs of your project is next on the list to be implemented.
 * This gem has not been tested with the Dive into Hydra tutorial.
 * The unit and integration tests have yet to be completed. 
 * This gem does not yet support facilitating testing in the same way that jettywrapper does.

## Dive into Hydra idiosyncracies

 * In order to start a dive-into-hydra project:
   1. Use `rails new <project name> --skip-bundle` otherwise you'll be prompted for you sudo pw 
   2. Change directory into your project dir.
   3. Make the additions to the Gemfile (see below for copy/pastable)
     * add hydra dependency.
     * add & pin slop gem to less than version 4.0
     * add umichwrapper depenency.
     * add preemptive dependencies to work around a bundler related issue.
   4. Run `bundle install --path=.bundle` (bundler suggests vendor/bundle)
   5. Run `rails generate hydra:install` 
   6. Update solr.yml and fedora.yml

 * Additions to your project's gemfile:
```
# Primary Hydra Dependency
gem 'hydra', '9.0.0'
# Pin slop to 3.x series for ruby 1.9.3 (jruby) compatibility
gem 'slop', '< 4.0'

# UMichwrapper
gem 'umichwrapper', github: 'grosscol/umichwrapper', branch: 'master'

# Preemptively require gems so that rails generate hydra:install will complete.
#   This is a vendorized gems issue with Bundle.with_clean_env
gem 'orm_adapter'
gem 'responders'
gem 'warden'
gem 'devise'
gem 'devise-guests', '~> 0.3'
gem 'bcrypt'
gem 'thread-safe'
```

 * If the gems are not installed preemptively, running `rails generate hydra:install` barfs during the `generate blacklight:install` phase with errors about gems not being found.

 * On Jruby, you cannot re-run `rails g hydra:install`.  The file conflict resolution will hang indefinitely as it's relying on Open3.  Using c ruby as a viable rescue for this scenario.

 * Errors during rails generate about "Could not find gem 'bundler'" can be ignored so long as you have already installed the gems that the call to bundle install from the generator would have installed.  It appears that this is a result of Bundle.with_clean_env being called from within a second tier Bundle environment (ENV -> Bundle -> Bundle).


