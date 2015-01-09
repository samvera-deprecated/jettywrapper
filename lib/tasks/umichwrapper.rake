## These tasks get loaded into the host application when jettywrapper is required
require 'yaml'

namespace :umich do
  JETTY_DIR = 'jetty'

  desc "download the jetty zip file"
  task :download do
    UMichwrapper.download
  end

  desc "unzip the downloaded jetty archive"
  task :unzip do
    UMichwrapper.unzip
  end

  desc "remove the jetty directory and recreate it"
  task :clean do
    UMichwrapper.clean
  end
  
  desc "Return the status of jetty"
  task :status => :environment do
    status = UMichwrapper.is_jetty_running?(JETTY_CONFIG) ? "Running: #{UMichwrapper.pid(JETTY_CONFIG)}" : "Not running"
    puts status
  end
  
  desc "Start jetty"
  task :start => :environment do
    UMichwrapper.start(JETTY_CONFIG)
    puts "jetty started at PID #{UMichwrapper.pid(JETTY_CONFIG)}"
  end
  
  desc "stop jetty"
  task :stop => :environment do
    UMichwrapper.stop(JETTY_CONFIG)
    puts "jetty stopped"
  end
  
  desc "Restarts jetty"
  task :restart => :environment do
    UMichwrapper.stop(JETTY_CONFIG)
    UMichwrapper.start(JETTY_CONFIG)
  end


  desc "Load the jetty config"
  task :environment do
    unless defined? JETTY_CONFIG
      JETTY_CONFIG = UMichwrapper.load_config
    end
  end

end

namespace :repo do



end
