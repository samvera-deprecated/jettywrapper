require 'fileutils'
require 'shellwords'
require 'erb'
require 'yaml'
require 'logger'

class Jettywrapper
  class Config

    attr_accessor :port         # Jetty's port.             Default: 8888
    alias :jetty_port :port     # would use alias_attribute, but Rails ain't guaranteed
    alias :jetty_port= :port=
    attr_accessor :startup_wait # Number of seconds to wait for jetty to spin up.  Default: 5
    attr_accessor :quiet        # Reduce Jetty's output.    Default: true
    attr_accessor :java_opts    # Options to pass to java.  ex. ["-Xmx512mb", "-Xms128mb"]
    attr_accessor :jetty_opts   # Options to pass to jetty. ex. ["etc/my_jetty.xml", "etc/other.xml"] as in http://wiki.eclipse.org/Jetty/Reference/jetty.xml_usage
    attr_accessor :base_path    # Root of the application, determining where logs and PID files should go.
    attr_accessor :tmp_dir      # Temp directory name (partial path).  Default: 'tmp'
    attr_accessor :jetty_dir    # Jetty directory name (partial path). Default: 'jetty'
    attr_accessor :jetty_home   # Jetty home directory.   Default: "#{base_path}/#{jetty_dir}"
    attr_accessor :solr_home    # Solr home directory.    Default: "#{jetty_home}/solr"

    attr_reader :hydra_jetty_version
    attr_writer :java_variables, :url, :env, :zip_file

    def initialize(params = {})
      base_path     = params[:base_path]    || app_root
      jetty_home    = params[:jetty_home]   || File.expand_path(File.join(base_path, 'jetty'))
      @base_path    = base_path
      @jetty_home   = jetty_home
      @quiet        = params[:quiet].nil? ? true : params[:quiet]
      @solr_home    = params[:solr_home]    || File.join(jetty_home, "solr") # can't just reference @jetty_home, because we're in initialize()
      @port         = params[:jetty_port]   || params[:port] || 8888
      @tmp_dir      = params[:tmp_dir]      || 'tmp'
      @jetty_dir    = params[:jetty_dir]    || 'jetty'
      @startup_wait = params[:startup_wait] || 5
      @java_opts    = params[:java_opts]    || []
      @jetty_opts   = params[:jetty_opts]   || []
      @hydra_jetty_version = params[:hydra_jetty_version] || 'v7.0.0'
      @url          = params[:url]      if not params[:url     ].nil?  # must be after hydra_jetty_version
      @zip_file     = params[:zip_file] if not params[:zip_file].nil?
    end

    def hydra_jetty_version= (ver)
      @hydra_jetty_version = ver
      @url = nil    # if you change the version, the old URL is wrong: nuke it.
    end

    def url
      @url ||= defined?(ZIP_URL) ? ZIP_URL : "https://github.com/projecthydra/hydra-jetty/archive/#{hydra_jetty_version}.zip"
      @url
    end

    def zip_file
      @zip_file ||= ENV['JETTY_ZIP'] || File.join(@tmp_dir, url.split('/').last)
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

    def load_config(config_name = env)
      @env = config_name
      jetty_file = "#{app_root}/config/jetty.yml"

      unless File.exists?(jetty_file)
        jetty_file2 = File.expand_path("../config/jetty.yml", File.dirname(__FILE__))
        logger.warn "jettywrapper expected config not found at:  #{jetty_file}"
        logger.warn "jettywrapper fallback to default config at: #{jetty_file2}"
        jetty_file = jetty_file2
      end

      begin
        jetty_erb = ERB.new(IO.read(jetty_file)).result(binding)
      rescue
        raise("#{jetty_file} was found, but could not be parsed with ERB.\n#{$!.inspect}")
      end

      begin
        jetty_yml = YAML::load(jetty_erb)
      rescue
        raise("#{jetty_file} was found, but could not be parsed.\n#{$!.inspect}")
      end

      if jetty_yml.nil? || !jetty_yml.is_a?(Hash)
        raise("#{jetty_file} was found, but was blank or malformed.\n")
      end

      config = jetty_yml.with_indifferent_access
      config[config_name] || config['default'.freeze]
    end

    def logger=(logger)
      @@logger = logger
    end

    # If ::Rails.logger is defined and is not nil, it will be returned.
    # If no logger has been defined, a new STDOUT Logger will be created.
    def logger
      @@logger ||= defined?(::Rails) && Rails.logger ? ::Rails.logger : ::Logger.new(STDOUT)
    end

    # What command is being run to invoke jetty?
    def jetty_command
      ["java", java_variables, java_opts, "-jar", "start.jar", jetty_opts].flatten
    end

    def java_variables
      @java_variables ||= ["-Djetty.port=#{@port}",
       "-Dsolr.solr.home=#{Shellwords.escape(@solr_home)}"]
    end

    def download(url = nil)
      @url = url if url
      logger.info "Downloading jetty from #{@url} ..."
      FileUtils.mkdir @tmp_dir unless File.exists? @tmp_dir
      system "curl -L #{self.url} -o #{zip_file}"
      abort "Unable to download jetty from #{self.url}" unless $?.success?
    end

    def unzip
      download unless File.exists? zip_file
      logger.info "Unpacking #{zip_file}..."
      tmp_save_dir = File.join @tmp_dir, 'jetty_generator'
      system "unzip -d #{tmp_save_dir} -qo #{zip_file}"
      abort "Unable to unzip #{zip_file} into tmp_save_dir/" unless $?.success?

      # Remove the old jetty directory if it exists
      system "rm -r #{jetty_dir}" if File.directory?(jetty_dir)

      # Move the expanded zip file into the final destination.
      expanded_dir = expanded_zip_dir(tmp_save_dir)
      system "mv #{expanded_dir} #{jetty_dir}"
      abort "Unable to move #{expanded_dir} into #{jetty_dir}/" unless $?.success?
    end

    def expanded_zip_dir(tmp_save_dir)
      # This old way is more specific, but won't work for blacklight-jetty
      #expanded_dir = Dir[File.join(tmp_save_dir, "hydra-jetty-*")].first
      Dir[File.join(tmp_save_dir, "*")].first
    end

    def clean
      system "rm -rf #{jetty_dir}"
      unzip
    end

    # Take the @jetty_home value and transform it into a legal filename
    # @return [String] the name of the pid_file
    # @example
    #    /usr/local/jetty1 => _usr_local_jetty1.pid
    def jetty_home_to_pid_file(jetty_home)
      begin
        jetty_home.gsub(/\//,'_') << "_#{env}" << ".pid"
      rescue Exception => e
        raise "Couldn't make a pid file for jetty_home value #{jetty_home}\n  Caused by: #{e}"
      end
    end

    # The directory where the pid_file will be written
    def pid_dir
      File.expand_path(File.join(base_path,@tmp_dir,'pids'))
    end

    # Check to see if there is a pid file already
    # @return true if the file exists, otherwise false
    def pid_file?
      File.exist?(pid_path)
    end

    # the process id of the currently running jetty instance
    def pid
      File.open( pid_path ) { |f| return f.gets.to_i } if File.exist?(pid_path)
    end
  end
end
