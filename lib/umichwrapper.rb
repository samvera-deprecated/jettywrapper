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
  attr_accessor :fedora_url, :solr_admin_url
  attr_accessor :tomcat_url, :tomcat_usr, :tomcat_pwd
  attr_accessor :solr_admin_url, :fedora_rest_url, :tomcat_admin_url
  attr_accessor :solr_core_name, :fedora_node_path
  attr_accessor :solr_home # Home directory for solr. Cores get added here.
  attr_accessor :app_name, :app_base_path
  attr_accessor :dist_dir
  attr_accessor :base_path

  # configure the singleton with some defaults
  def initialize(params = {})
    self.base_path = self.class.app_root
  end

  # Methods inside of the class << self block can be called directly on UMichwrapper, as class methods.
  # Methods outside the class << self block must be called on UMichwrapper.instance, as instance methods.
  class << self

    attr_writer :hydra_jetty_version, :env

    def hydra_jetty_version
      @hydra_jetty_version ||= 'v7.0.0'
    end

    def reset_config
      @app_root = nil
      @env = nil
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

    def parse_config_file( infile )
      # If there is not file, return an empty config
      if File.exist?( infile ) == false
        return Hash.new.with_indifferent_access
      end

      # Attempt erb parse
      begin
        in_erb = ERB.new(IO.read(infile)).result(binding)
      rescue
        raise("#{infile} was found, but could not be parsed with ERB. \n#{$!.inspect}")
      end

      # Parse results as yaml
      begin
        in_yml = YAML::load(in_erb)
      rescue
        raise("#{infile} was found, but could not be parsed.\n")
      end

      # Check the result
      if in_yml.nil? || !in_yml.is_a?(Hash)
        raise("#{infile} was found, but was blank or malformed.\n")
      end

      in_yml
    end

    # Load default config.  Overwrite with found configuration
    def load_config(config_name = env() )
      @env = config_name
      logger.info "Load config.  @env = #{@env}."
      default_file = File.expand_path("../config/umich.yml", File.dirname(__FILE__))
      app_file     = "#{app_root}/config/umich.yml"
      fedora_file  = "#{app_root}/config/solr.yml"
      solr_file    = "#{app_root}/config/fedora.yml"

      umich_file   = "#{app_root}/config/umich.yml"

      # Read default config endogenous to this gem
      sum_config = parse_config_file( default_file )

      # Read additional possible configs from app config
      app_config    = parse_config_file(app_file)    
      solr_config   = parse_config_file(solr_file)   
      fedora_config = parse_config_file(fedora_file) 

      merge_logic = Proc.new do |key,old,new|  
        if old.is_a?(Hash) && new.is_a?(Hash)
          old.merge new
        else
          new
        end
      end

      # Merge hashes overwritting with app_config where applicable 
      sum_config.merge! app_config, &merge_logic
      #sum_config.merge! solr_config, &merge_logic
      #sum_config.merge! fedora_config,  &merge_logic

      # Add the indifferent access magic from ActiveSupport.
      config = sum_config.with_indifferent_access
      config[config_name] || config['default'.freeze]
    end


    # Set the parameters for the instance.
    # @note tupac represents the one and only wrapper instance.
    #
    # @return instance
    #
    # @param [Hash<Symbol>] params
    #   :solr_host is the name of the server on which solr is running.
    #   :solr_port is the port number on which solr is listening.
    #
    #   :fedora_host
    #   :fedora_port
    #
    #   :fedora_url the user specific url which will have test|dev appended.
    #   :solr_admin_url   the user specific url which will have test|dev appended.
    #
    #   :startup_wait How many seconds to wait before starting tests. Deployment may take a while.
    def configure(params)
      params ||= {}
      tupac = self.instance

      # Params for Solr
      tupac.solr_admin_url = params[:solr_admin_url] || "localhost:8080/tomcat/quod-dev/solr-hydra"
      tupac.solr_admin_url   = "#{tupac.solr_admin_url}/admin" 
      tupac.solr_home = params[:solr_home] || "/quod-dev/idx/h/hydra-solr"

      # Params for Fedora
      tupac.fedora_url = params[:fedora_url] || "localhost:8080/tomcat/quod-dev/fedora"
      tupac.fedora_rest_url   = "#{tupac.fedora_url}/rest" 

      # Params for App Server
      tupac.tomcat_url = params[:tomcat_url] || "localhost:8080"
      tupac.tomcat_usr = params[:tomcat_usr] || "tomcat-manager"
      tupac.tomcat_pwd = params[:tomcat_pwd] || "YouNeedToChangeThisOrFaceThe401"
      tupac.startup_wait = params[:startup_wait] || 5
      tupac.dist_dir = params[:dist_dir] || "dist"
      tupac.app_base_path = params[:app_base_path] || "/tomcat/quod-dev/#{ENV['USER']}.quod.lib/hydra"
      # Discovered Parameters
      tupac.app_name   = params[:app_name]   || File.basename( tupac.base_path )

      # Params without required defaults.
      tupac.solr_core_name = params[:solr_core_name]
      tupac.fedora_node_path = params[:fedora_node_path]
      
      return tupac
    end

    def print_status(params = {})
      tupac = configure( params )
      puts "solr_admin_url: #{tupac.solr_admin_url}"
      puts "fedora_url:     #{tupac.fedora_url}"
      puts "--"
      puts "tomcat_url:     #{tupac.tomcat_url}"
      puts "tomcat_usr:     #{tupac.tomcat_usr}"
      puts "tomcat_pwd:     #{tupac.tomcat_pwd}"
      puts "--"
      puts "startup_wait:   #{tupac.startup_wait}"
      puts "app_name:       #{tupac.app_name}"
      puts "app_root:       #{UMichwrapper.app_root}"
      puts "-- Application  --"
      puts "app_path:       #{tupac.app_base_path}/#{tupac.app_name}"
      puts "solr running:   #{tupac.solr_running?|| 'false'}"
      puts "app deployed:   #{tupac.is_deployed? || 'false'}"

      puts "-- Solr Cores   --"
      tupac.core_status.each{|core, info| puts "#{info["instanceDir"]} :: #{core}"}
      puts "-- Fedora Nodes --"
      tupac.node_childs.each{|c| puts "#{c["@id"]}" }
    end

    # Convenience method for configuring solr & fedora and deploying application with one command
    # @param [Hash] params: The configuration 
    def start(params)
      UMichwrapper.configure(params)
      UMichwrapper.instance.add_core
      UMichwrapper.instance.add_node
      UMichwrapper.instance.deploy_app
      return UMichwrapper.instance
    end

    # Convenience method for create solr core and fedora node
    def setup(params)
      UMichwrapper.configure(params)
      UMichwrapper.intstance.add_core
      UMichwrapper.intstance.add_node
      return UMichwrapper.instance
    end

    def deploy(params)
      UMichwrapper.configure(params)
      UMichwrapper.instance.deploy_app
    end

    def clean(params)
      UMichwrapper.configure(params)
      UMichwrapper.instance.del_core
      UMichwrapper.instance.del_node
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
    
    if resp.response_code == 200
      body = JSON.parse!(resp.response_body)
      # Array of two elements [name string, info hash]
      return body["status"]
    else
      logger.error("Core status query url: #{target_url}")
      logger.error("Core status query response error.  Response code #{resp.response_code}")
      return []
    end
  end

  def del_core
    cname = "#{ENV['USER']}-#{corename}"
    # API call to unload core with Solr instance.
    vars = {
      action: "UNLOAD",
      core: cname,
      wt: "json"}

    target_url = "#{self.solr_admin_url}/cores"
    resp = Typhoeus.get(target_url, params: vars)

    body = JSON.parse!(resp.response_body)
    if body["error"]
      logger.warn body["error"]
    else
      logger.info "Core [#{cname}] unloaded."
    end

    # Remove core directory from file system
    core_inst_dir = File.join( self.solr_home, ENV['USER'], cname )
    logger.info "Deleting dir: #{core_inst_dir}"

    FileUtils.rm_rf( core_inst_dir )
  end

  def corename
    name = self.solr_core_name || env_fullname( UMichwrapper.env )
  end

  def nodename
    name = self.fedora_node_path || env_fullname( UMichwrapper.env )
  end

  def env_fullname( env )
    case env
    when /^dev(elopment)?/i
      "dev"
    when /^test(ing)?/i
      "test"
    else
      'default'
    end
  end

  def add_core
    # Get core instance dir for user/project
    cname = "#{ENV['USER']}-#{corename}"
    core_inst_dir = File.join( self.solr_home, ENV['USER'], cname )

    logger.debug "Adding solr core #{cname}"
    # Check if core already exists
    cs = core_status
    instance_dirs =  cs.collect{ |arr| arr[1]["instanceDir"].chop }

    # Short circut if core already exists in Solr instance.
    if instance_dirs.include? core_inst_dir
      logger.info "Core #{cname} alerady exists."
      return
    end

    # File operation to copy dir and files from template
    # Check for solr_cores/corename template in current directory
    if Dir.exist? File.join("solr_coresn", corename)
      logger.info "Using project solr_cores template."
      src  = File.join("solr_cores", corename)
    else
      logger.info "Using default solr_cores template."
      src  = File.join( File.expand_path("../../solr_cores", __FILE__), corename )
    end
    
    # Create core_inst_dir directory parent on the file system.
    FileUtils.mkdir_p( File.expand_path("..", core_inst_dir) )

    # Copy contents of template source to core instance directory
    FileUtils.cp_r(src, core_inst_dir)
    logger.info "Core template: #{src}"
    logger.info "Core instance: #{core_inst_dir}"

    # API call to register new core with Solr instance.
    # Sometimes core discovery is flakey, so ignore an error response here.
    vars = {
      action: "CREATE",
      name: cname,
      instanceDir: core_inst_dir,
      wt: "json"}

    target_url = "#{self.solr_admin_url}/cores"
    resp = Typhoeus.get(target_url, params: vars)

    body = JSON.parse!(resp.response_body)
    if body["error"]
      logger.warn body["error"]
    else
      logger.info "Core [#{cname}] added."
    end
  end

  # Querying the admin url should get you a redirect to hydra-solr/#
  def solr_running?
    resp = Typhoeus.get(self.solr_admin_url)
    return resp.response_code == 301
  end

  # Add fedora container node
  def add_node
    nname ="#{nodename}" 
    heads = { 'Content-Type' => "text/turtle" }
    bodyrdf = "PREFIX dc: <http://purl.org/dc/elements/1.1/> <> dc:title \"#{nname}-root\""
    target_url = "#{self.fedora_rest_url}/#{ENV["USER"]}/#{nname}"
    
    # Create the node with a put call
    resp = Typhoeus.put(target_url, headers: heads, body: bodyrdf)

    logger.info "Add node [#{nname}] response: #{resp.response_code}."
  end

  # Delete fedora node
  def del_node
    # Delete the node
    heads = { 'Content-Type' => "text/plain" }
    nname ="#{nodename}" 
    target_url = "#{self.fedora_rest_url}/#{ENV["USER"]}/#{nname}"
    
    resp = Typhoeus.delete(target_url, headers: heads)

    # 204 for success 404 for already deleted
    logger.info "Delete node [#{nname}] response code: #{resp.response_code}. "

    # Delete tombstone
    target_url = "#{self.fedora_rest_url}/#{ENV["USER"]}/#{nname}/fcr:tombstone"
    resp = Typhoeus.delete(target_url, headers: heads)

    # 204 for success. 404 for already deleted.
    logger.info "Delete tombstone for [#{nname}] response code: #{resp.response_code}. "
  end

  # Check if fedora node exists
  def node_exists?
    heads = { 'Content-Type' => "text/plain" }
    nname ="#{ENV["USER"]}-#{nodename}" 
    target_url = "#{self.fedora_rest_url}/#{ENV["USER"]}/#{nname}"
    
    resp = Typhoeus.get(target_url, headers: heads)

    return resp.response_code == 200
  end

  def node_childs()
    heads = { 'Accept' => "application/ld+json" }
    target_url = "#{self.fedora_rest_url}/#{ENV["USER"]}"
    
    resp = Typhoeus.get(target_url, headers: heads)
    
    # Return an empty array if request was not successful.
    if resp.response_code != 200
      logger.error("Node child query url: #{target_url}")
      logger.error("Node child query response error.  Response code #{resp.response_code}")
      return []
    end

    # Parse the body of the response for ldp#contains, or return an empty array
    body = JSON.parse! resp.response_body 
    return body[1]["http://www.w3.org/ns/ldp#contains"] || []
  end

  def logger
    self.class.logger
  end

  def is_deployed?
    app_path = "#{self.app_base_path}/#{self.app_name}"
    target_url = "#{self.tomcat_url}/manager/text/list"
    upwd = "#{self.tomcat_usr}:#{self.tomcat_pwd}"
    resp = Typhoeus.get(target_url, userpwd: upwd)

    if resp.response_code == 401
      logger.error "Tomcat: 401 authentication not accepted.  Check tomcat_user and tomcat_pwd in config."
    end

    # Return true if the response was OK and the app_path was found in the string.
    return resp.response_code == 200 && resp.body.match(app_path)

  end

  # Deploy war file to tomcat application server using management api
  #
  def deploy_app
    war_path = File.absolute_path File.join("dist", "demoname.war")
    app_name = self.app_name

    logger.info "Deploying application using the following parameters: "
    logger.info "  app_name: #{app_name}"
    logger.info "  war_path: #{war_path}"

    # parameters for api call
    upwd = "#{self.tomcat_usr}:#{self.tomcat_pwd}"
    target_url = "#{self.tomcat_url}/manager/text/deploy"
    vars = {war: "file:/#{war_path}", path: "#{self.app_base_path}/#{self.app_name}" }

    # Check if this is deployed on the tomcat server
    # and update & restart
    if File.exist?(war_path) == false
      logger.error "War file does not exist.  Aborting deployment."
    elsif is_deployed?
      logger.info "Application already deployed on tomcat.  Updating."
      vars[:update]="true"
      resp = Typhoeus.get(target_url, userpwd: upwd, params: vars)
      logger.info "Response: #{resp.body}"
    else
      resp = Typhoeus.get(target_url, userpwd: upwd, params: vars )
      logger.info "Response: #{resp.body}"
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
        sleep 10
      end
    end
    rescue Timeout::Error
      logger.warn "App not deployed after #{self.startup_wait * 10} seconds. Continuing anyway."
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
    app_name = self.app_name

    upwd = "#{self.tomcat_usr}:#{self.tomcat_pwd}"
    target_url = "#{self.tomcat_url}/manager/text/undeploy"
    vars = {path: "/tomcat/quod-dev/#{ENV['USER']}.quod.lib/hydra/#{app_name}" }

    if is_deployed?
      logger.info "Undeploying application: #{app_name}"
      resp = Typhoeus.get(target_url, userpwd: upwd, params: vars )
      logger.info "Response: #{resp.body}"
    else
      logger.info "Application #{app_name} not currently deployed."
    end
  end
end
