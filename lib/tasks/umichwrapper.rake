## These tasks get loaded into the host application when jettywrapper is required
require 'yaml'

namespace :umich do
  JETTY_DIR = 'jetty'

  desc "Empty fedora node and solr index."
  task :clean do
    UMichwrapper.clean
  end
  
  desc "Return the status of application deployment on torquebox."
  task :status => :environment do
    status = UMichwrapper.is_jetty_running?(JETTY_CONFIG) ? "Running: #{UMichwrapper.pid(JETTY_CONFIG)}" : "Not running"
    puts status
  end
  
  desc "Deploy and start application on torquebox."
  task :start => :environment do
    UMichwrapper.start(JETTY_CONFIG)
    puts "jetty started at PID #{UMichwrapper.pid(JETTY_CONFIG)}"
  end
  
  desc "Undeploy and stop application on torquebox."
  task :stop => :environment do
    UMichwrapper.stop(JETTY_CONFIG)
    puts "jetty stopped"
  end
  
  desc "Restarts application deployment on torquebox"
  task :restart => :environment do
    UMichwrapper.stop(JETTY_CONFIG)
    UMichwrapper.start(JETTY_CONFIG)
  end


  desc "Load the umich config."
  task :environment do
    unless defined? JETTY_CONFIG
      JETTY_CONFIG = UMichwrapper.load_config
    end
  end

end

namespace :repo do



end
