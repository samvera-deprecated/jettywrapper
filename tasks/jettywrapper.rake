# Note: These rake tasks are here mainly as examples to follow. You're going to want
# to write your own rake tasks that use the locations of your jetty instances. 

require 'jettywrapper'

namespace :jettywrapper do
  
  jetty1 = {
    :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../jetty1"),
    :jetty_port => "8983"
  }
  
  jetty2 = {
    :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../jetty2"),
    :jetty_port => "8984"
  }
  
  namespace :status do
    
    desc "Return the status of jetty1"
    task :jetty1 do
      status = Jettywrapper.is_running?(jetty1) ? "Running: #{Jettywrapper.pid(jetty1)}" : "Not running"
      puts status
    end
    
    desc "Return the status of jetty2"
    task :jetty2 do
      status = Jettywrapper.is_running?(jetty2) ? "Running: #{Jettywrapper.pid(jetty2)}" : "Not running"
      puts status
    end
    
  end
  
  namespace :start do
    
    desc "Start jetty1"
    task :jetty1 do
        Jettywrapper.start(jetty1)
        puts "jetty1 started at PID #{Jettywrapper.pid(jetty1)}"
    end
    
    desc "Start jetty2"
    task :jetty2 do
        Jettywrapper.start(jetty2)
        puts "jetty2 started at PID #{Jettywrapper.pid(jetty2)}"
    end
    
  end
  
  namespace :stop do
    
    desc "stop jetty1"
    task :jetty1 do
      Jettywrapper.stop(jetty1)
      puts "jetty1 stopped"
    end
    
    desc "stop jetty2"
    task :jetty2 do
      Jettywrapper.stop(jetty2)
      puts "jetty1 stopped"
    end
    
  end
  
  namespace :restart do
    
    desc "Restarts jetty1"
    task :jetty1 do
      Jettywrapper.stop(jetty1)
      Jettywrapper.start(jetty1)
    end
    
    desc "Restarts jetty2"
    task :jetty2 do
      Jettywrapper.stop(jetty2)
      Jettywrapper.start(jetty2)
    end
    
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