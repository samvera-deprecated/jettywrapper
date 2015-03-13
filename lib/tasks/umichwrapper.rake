require 'yaml'
require 'warbler'

## These tasks get loaded into the host application when umichwrapper is required
namespace :umich do
  desc "Stop application, empty fedora node, and delete solr core."
  task :clean => :environment do
    UMichwrapper.clean(UMICH_CONFIG)
  end

  desc "Start application after creating fedora node and solr cores."
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

  desc "Print the app status and environment config."
  task :status => :environment do
    UMichwrapper.print_status(UMICH_CONFIG)
  end

end

namespace :repo do



end
