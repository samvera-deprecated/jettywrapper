# Note: These rake tasks are here mainly as examples to follow. You're going to want
# to write your own rake tasks that use the locations of your jetty instances. 

require 'umichwrapper'

namespace :umichwrapper do
  
  umich_config = {
    :solr_home => "/path/to/solr"
    :torquebox_home => "/path/to/torquebox"
    :umich_port => "8983"
    :solr_url => "host:port/solr/uniquename"
    :fedora_url => "host:port/fcrepo/uniquename/dev"
  }
  
  desc "Return the status of this application on torquebox."
  task :status do
    status = umichwrapper.is_jetty_running?(umich_config) ? "Running." : "Not running."
    puts status
  end
  
  desc "Start application deployment on torquebox."
  task :start do
    umichwrapper.start(jetty)
    puts "jetty started at PID #{umichwrapper.pid(jetty)}"
  end
  
  desc "Stop application deployment on torquebox."
  task :stop do
    umichwrapper.stop(jetty)
    puts "application stopped and undeployed."
  end
  
  desc "Restart application on torquebox."
  task :restart do
    umichwrapper.stop(jetty)
    umichwrapper.start(jetty)
  end

  desc "Init Hydra configuration" 
  task :init => [:environment] do
    if !ENV["environment"].nil? 
      RAILS_ENV = ENV["environment"]
    end
    
    JETTY_HOME_TEST = File.expand_path(File.dirname(__FILE__) + '/../../jetty-test')
    JETTY_HOME_DEV = File.expand_path(File.dirname(__FILE__) + '/../../jetty-dev')
    
    JETTY_PARAMS_TEST = {
      :quiet => ENV['HYDRA_CONSOLE'] ? false : true,
      :jetty_home => JETTY_HOME_TEST,
      :jetty_port => 8983,
      :solr_home => File.expand_path(JETTY_HOME_TEST + '/solr'),
      :fedora_home => File.expand_path(JETTY_HOME_TEST + '/fedora/default')
    }

    JETTY_PARAMS_DEV = {
      :quiet => ENV['HYDRA_CONSOLE'] ? false : true,
      :jetty_home => JETTY_HOME_DEV,
      :jetty_port => 8984,
      :solr_home => File.expand_path(JETTY_HOME_DEV + '/solr'),
      :fedora_home => File.expand_path(JETTY_HOME_DEV + '/fedora/default')
    }
    
    # If Fedora Repository connection is not already initialized, initialize it using ActiveFedora defaults
    ActiveFedora.init unless Thread.current[:repo]  
  end

  desc "Copies the default SOLR config for the bundled jetty"
  task :config_solr => [:init] do
    FileList['solr/conf/*'].each do |f|  
      cp("#{f}", JETTY_PARAMS_TEST[:solr_home] + '/conf/', :verbose => true)
      cp("#{f}", JETTY_PARAMS_DEV[:solr_home] + '/conf/', :verbose => true)
    end
  end
  
  desc "Copies a custom fedora config for the bundled jetty"
  task :config_fedora => [:init] do
    fcfg = 'fedora/conf/fedora.fcfg'
    if File.exists?(fcfg)
      puts "copying over fedora.fcfg"
      cp("#{fcfg}", JETTY_PARAMS_TEST[:fedora_home] + '/server/config/', :verbose => true)
      cp("#{fcfg}", JETTY_PARAMS_DEV[:fedora_home] + '/server/config/', :verbose => true)
    else
      puts "#{fcfg} file not found -- skipping fedora config"
    end
  end
  
  desc "Copies the default Solr & Fedora configs into the bundled jetty"
  task :config do
    Rake::Task["hydra:jetty:config_fedora"].invoke
    Rake::Task["hydra:jetty:config_solr"].invoke
  end
end
