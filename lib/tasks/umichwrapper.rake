## These tasks get loaded into the host application when umichwrapper is required
require 'yaml'

namespace :umich do
  JETTY_DIR = 'jetty'

  desc "Check that the solr-fedora archive has been downloaded."
  task :download do
    UMichwrapper.download
  end

  desc "Wipe the umich directory and copy in fresh contents."
  task :clean do
    UMichwrapper.clean
  end
  
  desc "Return the status of application."
  task :status => :environment do
    status = UMichwrapper.status(UMICH_CONFIG)
    puts "Applications status: #{status}"
  end
  
  desc "Start application."
  task :start => :environment do
    UMichwrapper.start(UMICH_CONFIG)
  end
  
  desc "Stop application."
  task :stop => :environment do
    UMichwrapper.stop(UMICH_CONFIG)
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
    UMichwrapper.print_config(UMICH_CONFIG)
  end


end

namespace :repo do



end
