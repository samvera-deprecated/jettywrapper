require 'singleton'
require 'fileutils'
require 'timeout'
require 'erb'
require 'yaml'
require 'json'
require 'logger'
require 'typhoeus'
require 'active_support/core_ext/hash'


Dir[File.expand_path(File.join(File.dirname(__FILE__),"tasks/*.rake"))].each { |ext| load ext } if defined?(Rake)


# UMichwrapper is a Singleton class, so you can only create one instance at a time.
class UMichwrapper

  include Singleton

  attr_accessor :startup_wait # How many seconds to wait for jetty to spin up. Default is 5.
  attr_accessor :solr_home, :solr_host, :solr_port, :solr_cntx 
  attr_accessor :fedora_host, :fedora_port, :fedora_cntx 
  attr_accessor :solr_admin_url
  attr_accessor :fedora_rest_url
  attr_accessor :solr_core_name, :fedora_node_path
  attr_accessor :torq_home
  attr_accessor :app_name
  attr_accessor :deploy_dir
  attr_accessor :base_path

  # configure the singleton with some defaults
  def initialize(params = {})
    self.base_path = self.class.app_root
  end

  # Methods inside of the class << self block can be called directly on UMichwrapper, as class methods.
  # Methods outside the class << self block must be called on UMichwrapper.instance, as instance methods.
  class << self

    attr_writer :hydra_jetty_version, :url, :env

    def hydra_jetty_version
      @hydra_jetty_version ||= 'v7.0.0'
    end

    def reset_config
      @app_root = nil
      @env = nil
      @url = nil
      @hydra_jetty_version = nil
    end

    def app_root
      return @app_root if @app_root
      @app_root = Rails.root if defined?(Rails) and defined?(Rails.root)
      @app_root ||= APP_ROOT if defined?(APP_ROOT)
      @app_root ||= '.'
    end

    def env
      @env ||= begin
        case
        when ENV['JETTYWRAPPER_ENV']
          ENV['JETTYWRAPPER_ENV']
        when defined?(Rails) && Rails.respond_to?(:env)
          Rails.env
        when ENV['RAILS_ENV']
          ENV['RAILS_ENV']
        when ENV['environment']
          ENV['environment']
        else
          default_environment
        end
      end
    end

    def default_environment
      'development'
    end

    def load_config(config_name = env() )
      @env = config_name
      logger.info "Load config.  @env = #{@env}."
      umich_file = "#{app_root}/config/umich.yml"

      unless File.exists?(umich_file)
        logger.warn "Did not find umichwrapper config file #{umich_file}. Using default file instead."
        umich_file = File.expand_path("../config/umich.yml", File.dirname(__FILE__))
      end

      begin
        umich_erb = ERB.new(IO.read(umich_file)).result(binding)
      rescue
        raise("umich.yml was found, but could not be parsed with ERB. \n#{$!.inspect}")
      end

      begin
        umich_yml = YAML::load(umich_erb)
      rescue
        raise("umich.yml was found, but could not be parsed.\n")
      end

      if umich_yml.nil? || !umich_yml.is_a?(Hash)
        raise("umich.yml was found, but was blank or malformed.\n")
      end

      config = umich_yml.with_indifferent_access
      config[config_name] || config['default'.freeze]
    end

    # Set the parameters for the instance.
    # @note tupac represents the one and only wrapper instance.
    #
    # @return instance
    #
    # @param [Hash<Symbol>] params
    #   :torq_home is the root directory of torquebox.
    #
    #   :solr_host is the name of the server on which solr is running.
    #   :solr_port is the port number on which solr is listening.
    #
    #   :fedora_host
    #   :fedora_port
    #
    #   :fedora_url the user specific url which will have test|dev appended.
    #   :solr_url   the user specific url which will have test|dev appended.
    #
    #   :startup_wait How many seconds to wait before starting tests. Deployment may take a while.
    def configure(params)
      params ||= {}
      tupac = self.instance

      # Params with required defaults
      tupac.solr_home = params[:solr_home] || "/l/local/solr/#{ENV['USER']}"
      tupac.solr_host = params[:solr_host] || "localhost"
      tupac.solr_port = params[:solr_port] || 8080
      tupac.fedora_host = params[:fedora_host] || "localhost"
      tupac.fedora_port = params[:fedora_port] || 8080
      tupac.torq_home = params[:torq_home] || "/l/local/torquebox"
      tupac.startup_wait = params[:startup_wait] || 5

      # Derived Parameters
      tupac.app_name   = params[:app_name]   || File.basename( tupac.base_path )
      tupac.deploy_dir = params[:deploy_dir] || File.join( tupac.torq_home, "deployments" )
      tupac.fedora_cntx = params[:fedora_cntx] || "fedora"
      tupac.solr_cntx = params[:solr_cntx] || "hydra-solr"
      tupac.solr_admin_url   = "#{tupac.solr_host}:#{tupac.solr_port}/#{tupac.solr_cntx}/admin" 
      tupac.fedora_rest_url   = "#{tupac.fedora_host}:#{tupac.fedora_port}/#{tupac.fedora_cntx}/rest" 

      # Params without required defaults.
      tupac.solr_core_name = params[:solr_core_name]
      tupac.fedora_node_path = params[:fedora_node_path]
      
      return tupac
    end

    def print_status(params = {})
      tupac = configure( params )
      puts "solr_home:      #{tupac.solr_home}"
      puts "solr_host:      #{tupac.solr_host}"
      puts "solr_port:      #{tupac.solr_port}"
      puts "solr_cntx:      #{tupac.solr_cntx}"
      puts "--"
      puts "fedora_host:    #{tupac.fedora_host}"
      puts "fedora_port:    #{tupac.fedora_port}"
      puts "fedora_cntx:    #{tupac.fedora_cntx}"
      puts "--"
      puts "torq_home:      #{tupac.torq_home}"
      puts "startup_wait:   #{tupac.startup_wait}"
      puts "app_name:       #{tupac.app_name}"
      puts "deploy_dir:     #{tupac.deploy_dir}"
      puts "app_root:       #{UMichwrapper.app_root}"
      puts "-- Application --"
      puts "app deployed:   #{tupac.is_deployed?}"
      puts "-- Cores --"
      tupac.core_status.each{|core, info| puts "#{info["instanceDir"]} :: #{core}"}
      puts "-- Nodes --"
      tupac.node_childs.each{|c| puts "#{c["@id"]}" }
    end

    # Convenience method for configuring and starting jetty with one command
    # @param [Hash] params: The configuration to use for starting jetty
    # @example
    #    UMichwrapper.start(:jetty_home => '/path/to/jetty', :jetty_port => '8983')
    def start(params)
      UMichwrapper.configure(params)
      UMichwrapper.instance.add_core
      UMichwrapper.instance.add_node("dev")
      UMichwrapper.instance.add_node("test")
      UMichwrapper.instance.deploy_app
      return UMichwrapper.instance
    end

    def clean(params)
      UMichwrapper.configure(params)
      UMichwrapper.instance.del_core
      UMichwrapper.instance.del_node("dev")
      UMichwrapper.instance.del_node("test")
      UMichwrapper.instance.stop
      return UMichwrapper.instance
    end

    # Convenience method for configuring and starting jetty with one command. Note
    # that for stopping, only the :jetty_home value is required (including other values won't
    # hurt anything, though).
    # @param [Hash] params: The jetty_home to use for stopping jetty
    # @return [UMichwrapper.instance]
    # @example
    #    UMichwrapper.stop_with_params(:jetty_home => '/path/to/jetty')
    def stop(params)
       UMichwrapper.configure(params)
       UMichwrapper.instance.stop
       return UMichwrapper.instance
    end

    def logger=(logger)
      @@logger = logger
    end

    # If ::Rails.logger is defined and is not nil, it will be returned.
    # If no logger has been defined, a new STDOUT Logger will be created.
    def logger
      @@logger ||= defined?(::Rails) && Rails.logger ? ::Rails.logger : ::Logger.new(STDOUT)
    end

  end #end of class << self

  def core_status
    vars = {
      action: "STATUS", 
      wt: "json"}

    target_url = "#{self.solr_admin_url}/cores"
    resp = Typhoeus.get(target_url, params: vars)
    
    body = JSON.parse!(resp.response_body)

    # Array of two elements [name string, info hash]
    return body["status"]
  end

  def del_core
    # API call to unload core with Solr instance.
    vars = {
      action: "UNLOAD",
      core: corename,
      wt: "json"}

    target_url = "#{self.solr_admin_url}/cores"
    resp = Typhoeus.get(target_url, params: vars)

    body = JSON.parse!(resp.response_body)
    if body["error"]
      logger.warn body["error"]
    else
      logger.info "Core [#{corename}] unloaded."
    end

    # Remove core directory from file system
    core_inst_dir = File.join( self.solr_home, ENV['USER'], corename )
    logger.info "Deleting dir: #{core_inst_dir}"

    FileUtils.rm_rf( core_inst_dir )
  end

  def corename
    # If solr_core_name is specified, use that.
    if self.solr_core_name
      return self.solr_core_name
    end

    # Otherwise, consult the environment
    case UMichwrapper.env
    when /^dev(elopment)?/i
      name = "dev"
    when /^test(ing)?/i
      name = "test"
    else
      name = 'default'
    end

    return "#{ENV['USER']}-#{name}"
  end

  def template_corename
    case UMichwrapper.env
    when /^dev(elopment)?/i
      name = "dev"
    when /^test(ing)?/i
      name = "test"
    else
      name = 'default'
    end
    return name
  end

  def add_core()
    # Get core instance dir for user/project
    core_inst_dir = File.join( self.solr_home, ENV['USER'], corename )

    # Check if core already exists
    cs = core_status
    instance_dirs =  cs.collect{ |arr| arr[1]["instanceDir"].chop }

    # Short circut if core already exists in Solr instance.
    if instance_dirs.include? core_inst_dir
      logger.info "Core #{ENV['USER']} #{corename} alerady exists."
      return
    end

    # Create core_inst_dir directory on the file system.

    # File operation to copy dir and files from template
    # Check for solr_cores/corename template in current directory
    if Dir.exist? File.join("solr_coresn", template_corename)
      logger.info "Using project solr_cores template."
      src  = File.join("solr_cores", template_corename)
    else
      logger.info "Using default solr_cores template."
      src  = File.join( File.expand_path("../../solr_cores", __FILE__), template_corename )
    end
    
    # Copy contents of template source to core instance directory
    FileUtils.cp_r(src, core_inst_dir)
    logger.info "Core template: #{src}"
    logger.info "Core instance: #{core_inst_dir}"

    # API call to register new core with Solr instance.
    # Sometimes core discovery is flakey, so ignore an error response here.
    vars = {
      action: "CREATE",
      name: corename,
      instanceDir: core_inst_dir,
      wt: "json"}

    target_url = "#{self.solr_admin_url}/cores"
    resp = Typhoeus.get(target_url, params: vars)

    body = JSON.parse!(resp.response_body)
    if body["error"]
      logger.warn body["error"]
    else
      logger.info "Core [#{corename}] added."
    end
  end

  # Querying the admin url should get you a redirect to hydra-solr/#
  def solr_running?
    resp = Typhoeus.get(self.solr_admin_url)
    return resp.response_code == 301
  end

  # Add fedora node
  def add_node(node_name="dev")
    # Create the node
    heads = { 'Content-Type' => "text/plain" }
    target_url = "#{self.fedora_rest_url}/#{ENV["USER"]}/#{node_name}"
    
    resp = Typhoeus.put(target_url, headers: heads)

    logger.info "Add node [#{node_name}] response: #{resp.response_code}."
  end

  # Delete fedora node
  def del_node(node_name="dev")
    # Delete the node
    heads = { 'Content-Type' => "text/plain" }
    target_url = "#{self.fedora_rest_url}/#{ENV["USER"]}/#{node_name}"
    
    resp = Typhoeus.delete(target_url, headers: heads)

    # 204 for success 404 for already deleted
    logger.info "Delete node [#{node_name}] response code: #{resp.response_code}. "

    # Delete tombstone
    target_url = "#{self.fedora_rest_url}/#{ENV["USER"]}/#{node_name}/fcr:tombstone"
    resp = Typhoeus.delete(target_url, headers: heads)

    # 204 for success. 404 for already deleted.
    logger.info "Delete tombstone for [#{node_name}] response code: #{resp.response_code}. "
  end

  # Check if fedora node exists
  def node_exists?(node_name="dev")
    heads = { 'Content-Type' => "text/plain" }
    target_url = "#{self.fedora_rest_url}/#{ENV["USER"]}/#{node_name}"
    
    resp = Typhoeus.get(target_url, headers: heads)

    return resp.response_code == 200
  end

  def node_childs()
    heads = { 'Accept' => "application/ld+json" }
    target_url = "#{self.fedora_rest_url}/#{ENV["USER"]}"
    
    resp = Typhoeus.get(target_url, headers: heads)
    
    # Return an empty array if request was not successful.
    if resp.response_code != 200
      return []
    end

    # Parse the body of the response for ldp#contains, or return an empty array
    body = JSON.parse! resp.response_body 
    return body[1]["http://www.w3.org/ns/ldp#contains"] || []
  end

  def logger
    self.class.logger
  end

  # Check to see if the application is deployed.
  def is_deployed?(params = {})
    if !File.exists? self.deploy_dir
      raise("Torquebox deployment dir does not exist: #{self.deploy_dir}")
    end

    knob_path = File.join(self.deploy_dir, "#{ENV['USER']}-#{self.app_name}-knob.yml.deployed")
    return File.exist? knob_path
  end

  # This is the instance start method. It must be called on UMichwrapper.instance
  # You're probably better off using UMichwrapper.start()
  # @example
  #    UMichwrapper.configure(params)
  #    UMichwrapper.instance.start
  #    return UMichwrapper.instance
  # Make sure that Solr and Fedora cores and nodes are in order.
  def deploy_app
    app_name = self.app_name
    deploy_dir = File.join( self.torq_home, "deployments" )

    logger.debug "Deploying application using the following parameters: "
    logger.debug "  app_name: #{app_name}"
    logger.debug "  deploy_dir: #{deploy_dir}"

    # Check to see if we can start.
    # 0. Torquebox deployments exists and is writable.
    # 1. If a .deployed file exists, app is already deployed.
    if is_deployed?
      logger.info "Application already deployed."
      return
    end

    # If -knob.yml.failed is present, previous deployment failed.

    # Write -knob.yml if not present and touch -know.yml.dodeploy
    deploy_yaml

    # Wait until -knob.yml.deployed or -knob.yml.failed appears
    startup_wait!
  end

  def deployment_descriptor()
    ddir = self.deploy_dir
    appn = self.app_name

    # The deployment descriptor is a hash
    d = {}
    d['application'] = {}
    d['application']['root'] = "#{UMichwrapper.app_root}"
    d['environment'] = {}
    d['environment']['RAILS_ENV'] =  "development"
    d['environment']['RAILS_RELATIVE_URL_ROOT'] = "/"

    d['web'] = {}
    d['web']['context'] = "tb/quod-dev/#{ENV['USER']}.quod.lib/testapp/"

    return d
  end

  def deploy_yaml(clobber=false)
    knobname = "#{ENV['USER']}-#{self.app_name}-knob.yml"
    knob_file_path = File.join(self.deploy_dir, knobname)

    # Only write the knob file if file doesn't exist or clober is true
    if !File.exist?(knob_file_path) || clobber == true
      File.open( knob_file_path, 'w' ) do |file|
        YAML.dump( deployment_descriptor, file )
      end
    end
    FileUtils.touch( "#{knob_file_path}.dodeploy" )
  end

  def undeploy_yaml
    knobname = "#{ENV['USER']}-#{self.app_name}-knob.yml"
    knob_file_path = File.join(self.deploy_dir, knobname)

    Dir.glob("#{knob_file_path}*") do |p|
      File.delete(p)
      logger.info "Found & removed #{p}"
    end
  end

  # Wait for the jetty server to start and begin listening for requests
  def startup_wait!
    count = 0
    logger.info "Waiting for application to deploy..."
    begin
    Timeout::timeout(self.startup_wait) do
      while is_deployed? == false do
        count = count + 1
        sleep 1
      end
    end
    rescue Timeout::Error
      logger.warn "App not deployed after #{self.startup_wait} seconds. Continuing anyway."
    end

    logger.info "App deployed after #{count} seconds."
  end

  # Instance stop method. Must be called on UMichwrapper.instance
  # You're probably better off using UMichwrapper.stop(:jetty_home => "/path/to/jetty")
  # @example
  #    UMichwrapper.configure(params)
  #    UMichwrapper.instance.stop
  #    return UMichwrapper.instance
  def stop
    app_name = File.basename(self.base_path)
    deploy_dir = File.join( self.torq_home, "deployments" )

    if is_deployed? == false
      logger.debug "#{app_name} is not currently deployed to #{deploy_dir}."
    end

    # Undeploy by removing -knob.yml.deployed file
    logger.debug "Un-deploying the following application:"
    logger.debug "app_name: #{app_name}"
    logger.debug "deploy_dir: #{deploy_dir}"
    undeploy_yaml

  end
end
