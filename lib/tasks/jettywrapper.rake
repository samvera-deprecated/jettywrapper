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
    unless defined? JETTY_CONFIG
      JETTY_CONFIG = Jettywrapper.load_config
    end
  end

end

namespace :repo do



end
