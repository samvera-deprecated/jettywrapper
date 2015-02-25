require 'singleton'
require 'fileutils'
require 'timeout'
require 'erb'
require 'yaml'
require 'logger'
require 'typhoeus'

Dir[File.expand_path(File.join(File.dirname(__FILE__),"tasks/*.rake"))].each { |ext| load ext } if defined?(Rake)


# UMichwrapper is a Singleton class, so you can only create one instance at a time.
class UMichwrapper

  include Singleton
  include ActiveSupport::Benchmarkable

  attr_accessor :startup_wait # How many seconds to wait for jetty to spin up. Default is 5.
  attr_accessor :solr_home, :solr_host, :solr_port, :solr_cntx, :solr_app_url
  attr_accessor :fedora_host, :fedora_port, :fedora_cntx, :fedora_app_url
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
      puts "Load config.  @env = #{@env}."
      umich_file = "#{app_root}/config/umich.yml"

      unless File.exists?(umich_file)
        logger.warn "Did not find umichwrapper config file at #{umich_file}. Using default file instead."
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
      tupac.fedora_cntx = params[:fedora_cntx] || "fcrepo"
      tupac.solr_cntx = params[:solr_cntx] || "hydra-solr"
      tupac.fedora_app_url = "#{tupac.fedora_host}:#{tupac.fedora_port}/#{tupac.fedora_cntx}/#{ENV['USER']}/#{tupac.app_name}"
      tupac.solr_app_url   = "#{tupac.solr_host}:#{tupac.solr_port}/#{tupac.solr_cntx}/#{ENV['USER']}-#{tupac.app_name}" 

      return tupac
    end

    def print_config(params = {})
      tupac = configure( params )
      puts "solr_home:      #{tupac.solr_home}"
      puts "solr_host:      #{tupac.solr_host}"
      puts "solr_port:      #{tupac.solr_port}"
      puts "solr_cntx:      #{tupac.solr_cntx}"
      puts "solr_app_url:   #{tupac.solr_app_url}"
      puts "--"
      puts "fedora_host:    #{tupac.fedora_host}"
      puts "fedora_port:    #{tupac.fedora_port}"
      puts "fedora_cntx:    #{tupac.fedora_cntx}"
      puts "fedora_app_url: #{tupac.fedora_app_url}"
      puts "--"
      puts "torq_home:      #{tupac.torq_home}"
      puts "startup_wait:   #{tupac.startup_wait}"
      puts "app_name:       #{tupac.app_name}"
      puts "deploy_dir:     #{tupac.deploy_dir}"
      puts "UMichwrapper.app_root: #{UMichwrapper.app_root}"
    end

    # Wrap the tests. Startup jetty, yield to the test task, capture any errors, shutdown
    # jetty, and return the error.
    # @example Using this method in a rake task
    #   require 'jettywrapper'
    #   desc "Spin up jetty and run tests against it"
    #   task :newtest do
    #     jetty_params = {
    #       :jetty_home => "/path/to/jetty",
    #       :quiet => false,
    #       :jetty_port => 8983,
    #       :startup_wait => 30,
    #       :jetty_opts => "/etc/jetty.xml"
    #     }
    #     error = UMichwrapper.wrap(jetty_params) do
    #       Rake::Task["rake:spec"].invoke
    #       Rake::Task["rake:cucumber"].invoke
    #     end
    #     raise "test failures: #{error}" if error
    #   end
    def wrap(params)
      error = false
      jetty_server = self.configure(params)

      begin
        jetty_server.start
        yield
      rescue
        error = $!
        logger.error "*** Error starting jetty: #{error}"
      ensure
        # puts "stopping jetty server"
        jetty_server.stop
      end

      raise error if error

      return error
    end

    # Convenience method for configuring and starting jetty with one command
    # @param [Hash] params: The configuration to use for starting jetty
    # @example
    #    UMichwrapper.start(:jetty_home => '/path/to/jetty', :jetty_port => '8983')
    def start(params)
      UMichwrapper.configure(params)
      UMichwrapper.instance.start
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

    # Determine whether the jetty at the given jetty_home is running
    # @param [Hash] params: :jetty_home is required. Which jetty do you want to check the status of?
    # @return [Boolean]
    # @example
    #    UMichwrapper.is_jetty_running?(:jetty_home => '/path/to/jetty')
    def is_jetty_running?(params)
      UMichwrapper.configure(params)
      pid = UMichwrapper.instance.pid
      return false unless pid
      true
    end

    # Return the pid of the specified jetty, or return nil if it isn't running
    # @param [Hash] params: :jetty_home is required.
    # @return [Fixnum] or [nil]
    # @example
    #    UMichwrapper.pid(:jetty_home => '/path/to/jetty')
    def pid(params)
      UMichwrapper.configure(params)
      pid = UMichwrapper.instance.pid
      return nil unless pid
      pid
    end

    # Check to see if the port is open so we can raise an error if we have a conflict
    # @param [Fixnum] port the port to check
    # @return [Boolean]
    # @example
    #  UMichwrapper.is_port_open?(8983)
    def is_port_in_use?(port)
      begin
        Timeout::timeout(1) do
          begin
            s = TCPSocket.new('127.0.0.1', port)
            s.close
            return true
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            return false
          rescue
            return false
          end
        end
      rescue Timeout::Error
      end

      return false
    end


    def logger=(logger)
      @@logger = logger
    end

    # If ::Rails.logger is defined and is not nil, it will be returned.
    # If no logger has been defined, a new STDOUT Logger will be created.
    def logger
      @@logger ||= defined?(::Rails) && Rails.logger ? ::Rails.logger : ::Logger.new(STDOUT)
    end

    
    def status(params)
      UMichwrapper.configure(params)
      return ["deployed","undeployed","failed",""]
    end



  end #end of class << self

  def logger
    self.class.logger
  end

  # Check to see if the application is deployed.
  def is_deployed?(params = {})
    ddir = self.deploy_dir
    appn = self.app_name

    if !File.exists? ddir
      raise("Torquebox deployment dir does not exist: #{ddir}")
    end

    if File.exist? File.join(ddir, "#{appn}-knob.yml.deployed")
      return true
    end

    return false
  end

  def deploy_solr()
    #https://cwiki.apache.org/confluence/display/solr/Collections+API
    #e.g.
    #http://localhost:8983/solr/admin/collections?action=CREATE&name=newCollection&numShards=2&replicationFactor=1
    # /admin/collections?action=CREATE: create a collection
    # /admin/collections?action=RELOAD: reload a collection
    # /admin/collections?action=DELETE: delete a collection
    Typhoeus.post("www.example.com/posts", body: { action: "CREATE", name: "CollectionName", numShards: "1", replicationFactor: "1"})

  end

  def deploy_fedora()

  end


  # This is the instance start method. It must be called on UMichwrapper.instance
  # You're probably better off using UMichwrapper.start()
  # @example
  #    UMichwrapper.configure(params)
  #    UMichwrapper.instance.start
  #    return UMichwrapper.instance
  # Make sure that Solr and Fedora cores and nodes are in order.
  def start
    app_name = self.app_name
    deploy_dir = File.join( self.torq_home, "deployments" )

    logger.debug "Deploying application using the following parameters: "
    logger.debug "app_name: #{app_name}"
    logger.debug "deploy_dir: #{deploy_dir}"

    deploy_solr
    deploy_fedora

    # Check to see if we can start.
    # 0. Torquebox deployments exists and is writable.
    # 1. If a .deployed file exists, app is already deployed.
    if is_deployed?
      puts "Application already deployed."
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
      puts "Found & removed #{p}"
    end
  end

  # Wait for the jetty server to start and begin listening for requests
  def startup_wait!
    begin
    Timeout::timeout(self.startup_wait) do
      sleep 1 until (is_deployed?)
    end
    rescue Timeout::Error
      logger.warn "App not deployed after #{self.startup_wait} seconds. Continuing anyway."
    end
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
