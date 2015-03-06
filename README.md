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

