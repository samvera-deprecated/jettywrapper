require 'yaml'

## These tasks get loaded into the host application when umichwrapper is required
namespace :umich do
  desc "Empty fedora node and delete solr core."
  task :clean => :environment do
    UMichwrapper.clean(UMICH_CONFIG)
  end

  # directory "dist"
  # directory "config"

  desc "Load the umich environment from config."
  task :environment do
    unless defined? UMICH_CONFIG
      UMICH_CONFIG = UMichwrapper.load_config
    end
  end

  desc "Setup solr core and fedora node."
  task :setup => :environment do
    UMichwrapper.setup(UMICH_CONFIG)
  end

  desc "Setup solr core only."
  task :solr => :environment do
    UMichwrapper.solr_only(UMICH_CONFIG)
  end

  desc "Setup fedora node only."
  task :fedora => :environment do
    UMichwrapper.fedora_only(UMICH_CONFIG)
  end

  desc "Print the app status and environment config."
  task :status => :environment do
    UMichwrapper.print_status(UMICH_CONFIG)
  end


end

