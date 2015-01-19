## These tasks get loaded into the host application when umichwrapper is required
require 'yaml'

namespace :umich do
  JETTY_DIR = 'jetty'

  desc "Empty fedora node and solr index."
  task :clean do
    UMichwrapper.clean
  end
  
  desc "Return the status of application."
  task :status => :environment do
    status = UMichwrapper.is_deployed?(UMICH_CONFIG) ? "App is deployed." : "App is NOT deployed."
    puts status
  end
  
  desc "Start application."
  task :start => :environment do
    UMichwrapper.start(UMICH_CONFIG)
    
    deploy_name = UMichwrapper.deploy_yaml(UMICH_CONFIG)
  
    puts "Deployed: #{deploy_name}"
  end
  
  desc "Stop application."
  task :stop => :environment do
    UMichwrapper.stop(UMICH_CONFIG)
    puts "jetty stopped"
  end
  
  desc "Restarts application."
  task :restart => :environment do
    UMichwrapper.stop(UMICH_CONFIG)
    UMichwrapper.start(UMICH_CONFIG)
  end

  desc "Load the umich environment from config."
  task :environment do
    unless defined? UMICH_CONFIG
      UMICH_CONFIG = UMichwrapper.load_config
    end
  end

  desc "Print the environment config."
  task :penv => :environment do
    UMichwrapper.print_config
  end


end

namespace :repo do



end
