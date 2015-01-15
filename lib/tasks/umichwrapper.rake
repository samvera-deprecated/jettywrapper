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
    status = UMichwrapper.is_jetty_running?(UMICH_CONFIG) ? "Running: #{UMichwrapper.pid(UMICH_CONFIG)}" : "Not running"
    puts status
  end
  
  desc "Start application."
  task :start => :environment do
    UMichwrapper.start(UMICH_CONFIG)
    
    descriptor = TorqueBox::DeployUtils.basic_deployment_descriptor( :context_path => args[:context_path] )
    deployment_name, deploy_dir = TorqueBox::DeployUtils.deploy_yaml( descriptor, args )
  
    puts "Deployed: #{deployment_name}"
    puts "    into: #{deploy_dir}"
  end
  
  desc "Deploy the app in the current directory"
  task :deploy, [:context_path, :name] => ['torquebox:check'] do |t, args|
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
