## These tasks get loaded into the host application when jettywrapper is required
require 'yaml'

namespace :jetty do
  
  desc "Return the status of jetty"
  task :status => :environment do
    status = Jettywrapper.is_jetty_running?(JETTY_CONFIG) ? "Running: #{Jettywrapper.pid(JETTY_CONFIG)}" : "Not running"
    puts status
  end
  
  desc "Start jetty"
  task :start => :environment do
    Jettywrapper.start(JETTY_CONFIG)
    puts "jetty started at PID #{Jettywrapper.pid(JETTY_CONFIG)}"
  end
  
  desc "stop jetty"
  task :stop => :environment do
    Jettywrapper.stop(JETTY_CONFIG)
    puts "jetty stopped"
  end
  
  desc "Restarts jetty"
  task :restart do
    Jettywrapper.stop(JETTY_CONFIG)
    Jettywrapper.start(JETTY_CONFIG)
  end


  desc "Load the jetty config"
  task :environment do
    unless Kernel.const_defined? "JETTY_CONFIG"
      if Kernel.const_defined? "Rails" 
        config_name =  Rails.env 
        app_root = Rails.root
      else 
        config_name =  ENV['environment']
        app_root = ENV['APP_ROOT']
        app_root ||= '.'
      end
      filename = "#{app_root}/config/jetty.yml"
      begin
        file = YAML.load_file(filename)
      rescue Exception => e
        logger.warn "Didn't find expected jettywrapper config file at #{filename}, using default file instead."
        file ||= YAML.load_file(File.join(File.dirname(__FILE__),"../../config/jetty.yml"))
        #raise "Unable to load: #{file}" unless file
      end
      JETTY_CONFIG = file.with_indifferent_access
    end
  end

end

namespace :repo do



end
