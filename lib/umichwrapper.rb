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

  attr_accessor :solr_admin_url, :fedora_url, :fedora_rest_url
  attr_accessor :solr_core_name, :fedora_node_path
  attr_accessor :solr_home # Home directory for solr. Cores get added here.
  attr_accessor :base_path # Base path of the application.

  # configure the singleton with some defaults
  def initialize(params = {})
    self.base_path = self.class.app_root
  end

  # Methods inside of the class << self block can be called directly on UMichwrapper, as class methods.
  # Methods outside the class << self block must be called on UMichwrapper.instance, as instance methods.
  class << self

    attr_writer :umichwrapper_version, :env

    def umichwrapper_version
      @umichwrapper_version ||= 'v1.0.0'
    end

    def reset_config
      @app_root = nil
      @env = nil
      @umichwrapper_version = nil
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
      fedora_file  = "#{app_root}/config/fedora.yml"
      solr_file    = "#{app_root}/config/solr.yml"

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

      # Merge default and app umich configs
      #  overwritting with app_config where applicable 
      sum_config.merge! app_config, &merge_logic

      # Add fedora and solr configs from matching config_name
      sum_config[config_name]['solr_cfg']   = solr_config[config_name]
      sum_config[config_name]['fedora_cfg'] = fedora_config[config_name]

      # Add the indifferent access magic from ActiveSupport.
      config = sum_config.with_indifferent_access
      config[config_name] || config['default'.freeze]
    end


    # Set the parameters for the instance.
    # Parameters are loaded in precendence solr|fedora > umich > default
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
    def configure(params)
      params ||= {}
      tupac = self.instance

      # Params Required for Solr
      tupac.solr_admin_url   = params[:solr_admin_url] || "localhost:8080/tomcat/quod-dev/solr-hydra/admin"
      tupac.solr_home        = params[:solr_home] || "/quod-dev/idx/h/hydra-solr"

      # Params Required for Fedora
      tupac.fedora_url       = params[:fedora_cfg][:url] || params[:fedora_url] || "localhost:8080/tomcat/quod-dev/fedora/rest"
      tupac.fedora_rest_url  = "#{tupac.fedora_url}" 

      # Params without required defaults.
      tupac.solr_core_name   = params[:solr_core_name]
      tupac.fedora_node_path = params[:fedora_cfg][:base_path] || params[:fedora_node_path]
      
      return tupac
    end

    def print_status(params = {})
      tupac = configure( params )
      puts "-- Application --"
      puts "solr_core_name:   #{tupac.solr_core_name}"
      puts "fedora_base_node: #{tupac.fedora_node_path}"
      puts "-- Service --"
      puts "solr_admin_url:   #{tupac.solr_admin_url}"
      puts "solr running:     #{tupac.solr_running? || 'false'}"
      puts "fedora_url:       #{tupac.fedora_url}"

      puts "-- Solr Cores   --"
      tupac.core_status.each{|core, info| puts "#{info["instanceDir"]} :: #{core}"}
      puts "-- Fedora Nodes --"
      tupac.node_childs.each{|c| puts "#{c["@id"]}" }
    end

    # Convenience method for create solr core and fedora node
    def setup(params)
      UMichwrapper.configure(params)
      UMichwrapper.instance.add_core
      UMichwrapper.instance.add_node
      return UMichwrapper.instance
    end

    def solr_only(params)
      UMichwrapper.configure(params)
      UMichwrapper.instance.add_core
      return UMichwrapper.instance
    end

    def fedora_only(params)
      UMichwrapper.configure(params)
      UMichwrapper.instance.add_node
      return UMichwrapper.instance
    end

    def clean(params)
      UMichwrapper.configure(params)
      UMichwrapper.instance.del_core
      UMichwrapper.instance.del_node
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
    name = self.solr_core_name || "#{ENV['USER']}-#{env_name(UMichwrapper.env)}"
  end

  def nodename
    name = self.fedora_node_path || "#{ENV['USER']}-#{env_name(UMichwrapper.env)}"
  end

  def env_name( env )
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
    core_inst_dir = File.join( self.solr_home, ENV['USER'], corename )

    logger.debug "Adding solr core #{corename}"
    # Check if core instance directory already exists
    cs = core_status
    instance_dirs =  cs.collect{ |arr| arr[1]["instanceDir"].chop }

    # Short circut if core instance directory already exists.
    if instance_dirs.include? core_inst_dir
      logger.info "Directory for #{corename} alerady exists."
      return
    end

    # File operation to copy dir and files from template
    # Check for solr_cores/corename template in current directory
    if Dir.exist? File.join("solr_cores", corename)
      logger.info "Using project solr_cores template."
      src  = File.join("solr_cores", corename)
    else
      logger.info "Using default solr_cores template."
      # Make sure src directory ends with trailing file separator so cp_r operates as expected
      src  = File.join( File.expand_path("../../solr_cores", __FILE__), corename, '' )
    end
    
    # Create core_inst_dir directory parent on the file system.
    core_inst_dir_parent = File.expand_path("..", core_inst_dir) 
    FileUtils.mkdir_p( core_inst_dir_parent )

    # Copy contents of template source to core instance directory
    FileUtils.cp_r(src, core_inst_dir, remove_destination: true)
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

  # Add fedora container node
  def add_node
    heads = { 'Content-Type' => "text/turtle" }
    bodyrdf = "PREFIX dc: <http://purl.org/dc/elements/1.1/> <> dc:title \"#{nodename}-root\""
    target_url = "#{self.fedora_rest_url}/#{nodename}"
    
    # Create the node with a put call
    resp = Typhoeus.put(target_url, headers: heads, body: bodyrdf)

    logger.info "Add node [#{nodename}] response: #{resp.response_code}."
  end

  # Delete fedora node
  def del_node
    # Delete the node
    heads = { 'Content-Type' => "text/plain" }
    target_url = "#{self.fedora_rest_url}/#{nodename}"
    
    resp = Typhoeus.delete(target_url, headers: heads)

    # 204 for success 404 for already deleted
    logger.info "Delete node [#{nodename}] response code: #{resp.response_code}. "

    # Delete tombstone
    target_url = "#{self.fedora_rest_url}/#{nodename}/fcr:tombstone"
    resp = Typhoeus.delete(target_url, headers: heads)

    # 204 for success. 404 for already deleted.
    logger.info "Delete tombstone for [#{nodename}] response code: #{resp.response_code}. "
  end

  # Check if fedora node exists
  def node_exists?
    heads = { 'Content-Type' => "text/plain" }
    target_url = "#{self.fedora_rest_url}/#{nodename}"
    
    resp = Typhoeus.get(target_url, headers: heads)

    return resp.response_code == 200
  end

  def node_childs()
    heads = { 'Accept' => "application/ld+json" }
    target_url = self.fedora_rest_url
    
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

end
