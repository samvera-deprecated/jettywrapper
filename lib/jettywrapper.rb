# Jettywrapper is a Singleton class, so you can only create one jetty instance at a time.
require 'loggable'
require 'singleton'
require 'fileutils'
require 'shellwords'
require 'socket'
require 'timeout'
require 'childprocess'
require 'active_support/core_ext/hash'

Dir[File.expand_path(File.join(File.dirname(__FILE__),"tasks/*.rake"))].each { |ext| load ext } if defined?(Rake)


class Jettywrapper
  
  include Singleton
  include Loggable
  
  attr_accessor :port         # What port should jetty start on? Default is 8888
  attr_accessor :jetty_home   # Where is jetty located? 
  attr_accessor :startup_wait # After jetty starts, how long to wait until starting the tests? 
  attr_accessor :quiet        # Keep quiet about jetty output?
  attr_accessor :solr_home    # Where is solr located? Default is jetty_home/solr
  attr_accessor :base_path    # The root of the application. Used for determining where log files and PID files should go.
  attr_accessor :java_opts    # Options to pass to java (ex. ["-Xmx512mb", "-Xms128mb"])
  
  # configure the singleton with some defaults
  def initialize(params = {})
    if defined?(Rails.root)
      @base_path = Rails.root
    else
      @base_path = "."
    end

    logger.debug 'Initializing jettywrapper'
  end
  
  # Methods inside of the class << self block can be called directly on Jettywrapper, as class methods. 
  # Methods outside the class << self block must be called on Jettywrapper.instance, as instance methods.
  class << self
    
    def load_config
      if defined? Rails 
        config_name =  Rails.env 
        app_root = Rails.root
      else 
        config_name =  ENV['environment']
        app_root = ENV['APP_ROOT']
        app_root ||= '.'
      end
      filename = "#{app_root}/config/jetty.yml"
      begin
        file = YAML.load_file(filename)
      rescue Exception => e
        logger.warn "Didn't find expected jettywrapper config file at #{filename}, using default file instead."
        file ||= YAML.load_file(File.join(File.dirname(__FILE__),"../config/jetty.yml"))
        #raise "Unable to load: #{file}" unless file
      end
      config = file.with_indifferent_access
      config[config_name] || config[:default]
    end
    

    # Set the jetty parameters. It accepts a Hash of symbols. 
    # @param [Hash<Symbol>] params
    # @param [Symbol] :jetty_home Required. Where is jetty located? 
    # @param [Symbol] :jetty_port What port should jetty start on? Default is 8888
    # @param [Symbol] :startup_wait After jetty starts, how long to wait before running tests? If you don't let jetty start all the way before running the tests, they'll fail because they can't reach jetty.
    # @param [Symbol] :solr_home Where is solr? Default is jetty_home/solr
    # @param [Symbol] :quiet Keep quiet about jetty output? Default is true. 
    # @param [Symbol] :java_opts A list of options to pass to the jvm 
    def configure(params = {})
      hydra_server = self.instance
      hydra_server.reset_process!
      hydra_server.quiet = params[:quiet].nil? ? true : params[:quiet]
      if defined?(Rails.root)
       base_path = Rails.root
      elsif defined?(APP_ROOT)
       base_path = APP_ROOT
      else
       raise "You must set either Rails.root, APP_ROOT or pass :jetty_home as a parameter so I know where jetty is" unless params[:jetty_home]
      end
      hydra_server.jetty_home = params[:jetty_home] || File.expand_path(File.join(base_path, 'jetty'))
      hydra_server.solr_home = params[:solr_home]  || File.join( hydra_server.jetty_home, "solr")
      hydra_server.port = params[:jetty_port] || 8888
      hydra_server.startup_wait = params[:startup_wait] || 5
      hydra_server.java_opts = params[:java_opts] || []
      return hydra_server
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
    #       :startup_wait => 30
    #     }
    #     error = Jettywrapper.wrap(jetty_params) do   
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
        sleep jetty_server.startup_wait
        yield
      rescue
        error = $!
        puts "*** Error starting hydra-jetty: #{error}"
      ensure
        # puts "stopping jetty server"
        jetty_server.stop
      end

      return error
    end
    
    # Convenience method for configuring and starting jetty with one command
    # @param [Hash] params: The configuration to use for starting jetty
    # @example 
    #    Jettywrapper.start(:jetty_home => '/path/to/jetty', :jetty_port => '8983')
    def start(params)
       Jettywrapper.configure(params)
       Jettywrapper.instance.start
       return Jettywrapper.instance
    end
    
    # Convenience method for configuring and starting jetty with one command. Note
    # that for stopping, only the :jetty_home value is required (including other values won't 
    # hurt anything, though). 
    # @param [Hash] params: The jetty_home to use for stopping jetty
    # @return [Jettywrapper.instance]
    # @example 
    #    Jettywrapper.stop_with_params(:jetty_home => '/path/to/jetty')
    def stop(params)
       Jettywrapper.configure(params)
       Jettywrapper.instance.stop
       return Jettywrapper.instance
    end
    
    # Determine whether the jetty at the given jetty_home is running
    # @param [Hash] params: :jetty_home is required. Which jetty do you want to check the status of?
    # @return [Boolean]
    # @example
    #    Jettywrapper.is_jetty_running?(:jetty_home => '/path/to/jetty')
    def is_jetty_running?(params)      
      Jettywrapper.configure(params)
      pid = Jettywrapper.instance.pid
      return false unless pid
      true
    end
    
    # Return the pid of the specified jetty, or return nil if it isn't running
    # @param [Hash] params: :jetty_home is required.
    # @return [Fixnum] or [nil]
    # @example
    #    Jettywrapper.pid(:jetty_home => '/path/to/jetty')
    def pid(params)
      Jettywrapper.configure(params)
      pid = Jettywrapper.instance.pid
      return nil unless pid
      pid
    end
    
    # Check to see if the port is open so we can raise an error if we have a conflict
    # @param [Fixnum] port the port to check
    # @return [Boolean]
    # @example
    #  Jettywrapper.is_port_open?(8983)
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
    
    # Check to see if the pid is actually running. This only works on unix. 
    def is_pid_running?(pid)
      begin
        return Process.getpgid(pid) != -1
      rescue Errno::ESRCH
        return false
      end
    end
    
    end #end of class << self
    
        
   # What command is being run to invoke jetty? 
   def jetty_command
     ["java", java_variables, java_opts, "-jar", "start.jar"].flatten
   end

   def java_variables
     ["-Djetty.port=#{@port}",
      "-Dsolr.solr.home=#{Shellwords.escape(@solr_home)}"]
   end

   # Start the jetty server. Check the pid file to see if it is running already, 
   # and stop it if so. After you start jetty, write the PID to a file. 
   # This is the instance start method. It must be called on Jettywrapper.instance
   # You're probably better off using Jettywrapper.start(:jetty_home => "/path/to/jetty")
   # @example
   #    Jettywrapper.configure(params)
   #    Jettywrapper.instance.start
   #    return Jettywrapper.instance
   def start
     logger.debug "Starting jetty with these values: "
     logger.debug "jetty_home: #{@jetty_home}"
     logger.debug "solr_home: #{@solr_home}"
     logger.debug "jetty_command: #{jetty_command.join(' ')}"
     
     # Check to see if we can start.
     # 1. If there is a pid, check to see if it is really running
     # 2. Check to see if anything is blocking the port we want to use     
     if pid
       if Jettywrapper.is_pid_running?(pid)
         raise("Server is already running with PID #{pid}")
       else
         logger.warn "Removing stale PID file at #{pid_path}"
         File.delete(pid_path)
       end
       if Jettywrapper.is_port_in_use?(@jetty_port)
         raise("Port #{self.jetty_port} is already in use.")
       end
     end
     Dir.chdir(@jetty_home) do
       process.start
     end
     FileUtils.makedirs(pid_dir) unless File.directory?(pid_dir)
     begin
       f = File.new(pid_path,  "w")
     rescue Errno::ENOENT, Errno::EACCES
       f = File.new(File.join(@base_path,'tmp',pid_file),"w")
     end
     f.puts "#{process.pid}"
     f.close
     logger.debug "Wrote pid file to #{pid_path} with value #{process.pid}"
   end
 
   def process
     @process ||= begin
        process = ChildProcess.build(*jetty_command)
        if self.quiet
          process.io.stderr = File.open("jettywrapper.log", "w+")
          process.io.stdout = process.io.stderr
           logger.warn "Logging jettywrapper stdout to #{File.expand_path(process.io.stderr.path)}"
        else
          process.io.inherit!
        end
        process.detach = true

        process
      end
   end

   def reset_process!
     @process = nil
   end
   # Instance stop method. Must be called on Jettywrapper.instance
   # You're probably better off using Jettywrapper.stop(:jetty_home => "/path/to/jetty")
   # @example
   #    Jettywrapper.configure(params)
   #    Jettywrapper.instance.stop
   #    return Jettywrapper.instance
   def stop    
     logger.debug "Instance stop method called for pid '#{pid}'"
     if pid
       if @process
         @process.stop
       else
         Process.kill("KILL", pid) rescue nil
       end

       begin
         File.delete(pid_path)
       rescue
       end
     end
   end
 

   # The fully qualified path to the pid_file
   def pid_path
     #need to memoize this, becasuse the base path could be relative and the cwd can change in the yield block of wrap
     @path ||= File.join(pid_dir, pid_file)
   end

   # The file where the process ID will be written
   def pid_file
     jetty_home_to_pid_file(@jetty_home)
   end
   
    # Take the @jetty_home value and transform it into a legal filename
    # @return [String] the name of the pid_file
    # @example
    #    /usr/local/jetty1 => _usr_local_jetty1.pid
    def jetty_home_to_pid_file(jetty_home)
      begin
        jetty_home.gsub(/\//,'_') << ".pid"
      rescue
        raise "Couldn't make a pid file for jetty_home value #{jetty_home}"
        raise $!
      end
    end

   # The directory where the pid_file will be written
   def pid_dir
     File.expand_path(File.join(@base_path,'tmp','pids'))
   end
   
   # Check to see if there is a pid file already
   # @return true if the file exists, otherwise false
   def pid_file?
      return true if File.exist?(pid_path)
      false
   end

   # the process id of the currently running jetty instance
   def pid
      File.open( pid_path ) { |f| return f.gets.to_i } if File.exist?(pid_path)
   end
   
end
