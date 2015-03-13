require 'yaml'
require 'warbler'

## These tasks get loaded into the host application when umichwrapper is required
namespace :umich do
  desc "Stop application, empty fedora node, and delete solr core."
  task :clean => :environment do
    UMichwrapper.clean(UMICH_CONFIG)
  end

  desc "Build war file."
  task :build do
    # copy config/warble if doesn't exist
    local_config = File.join 'config', 'warble.rb'
    if File.exist?(local_config ) == false
      puts "--- Needs a config/warble.rb"
      src = File.join File.expand_path( '../../../config',__FILE__), 'warble.rb'
      puts "Src  exists? #{File.exist? src}. #{src}"
      puts "Src: #{src}\nDst:#{local_config}"
      FileUtils.copy_file( src, local_config )
    end

    # shell out to warbler
    puts %x{warble}
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
