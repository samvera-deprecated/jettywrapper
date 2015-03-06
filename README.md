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

Add the UMichwrapper github repo to your project's Gemfile

```
# UMichwrapper
gem 'umichwrapper', github: 'grosscol/umichwrapper', branch: 'master'
```


## Notes

This does not yet read from solr.yml and fedora.yml in your project config.  However, those do need to point to the corresponding solr and fedora instance/context.  Currently keeping these both configured is on the developer.  Having the UMichwrapper read the solr and fedora configs of your project is next on the list to be implemented.

This has been tested with the Dive into Hydra tutorial.
  * Use `rails new <project name> --skip-bundle` otherwise you'll be prompted for you sudo pw 
    1. Change directories into your project dir.
    2. Edit the Gemfile and add the umichwrapper entry as detailed above.
    3. Run bundle install --path .bundle (bundler suggests vendor/bundle)

  * Add `gem 'slop', '< 4.0.0.0'` to the gemfile as slop 4.0 requires ruby 2.0
  * Add `gem 'devise'` to the gemfile to avoid a problem with the blacklight generator trying to call bundle

Running `rails generate hydra:install` barfs during the `generate blacklight:install` phase.
Errors about "Could not find 'bundler'" and then a number of other gems.  Seems this generator is unable to run bundle install.
Run bundle install again.
Re-run rails g hydra:install
  gets to a question about overwritting blacklight-initializers.rb.  Answering either 'y','n', or 'q' results in the process hanging.

