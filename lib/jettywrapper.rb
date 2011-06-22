# Jettywrapper is a Singleton class, so you can only create one jetty instance at a time.
require 'rubygems'
require 'logger'
require 'loggable'
require 'singleton'
require 'ftools'

class Jettywrapper
  
  include Singleton
  include Loggable
  
  attr_accessor :pid          # If Jettywrapper is running, what pid is it running as? 
  attr_accessor :port         # What port should jetty start on? Default is 8888
  attr_accessor :jetty_home   # Where is jetty located? 
  attr_accessor :startup_wait # After jetty starts, how long to wait until starting the tests? 
  attr_accessor :quiet        # Keep quiet about jetty output?
  attr_accessor :solr_home    # Where is solr located? Default is jetty_home/solr
  attr_accessor :fedora_home  # Where is fedora located? Default is jetty_home/fedora
  attr_accessor :logger       # Where should logs be written?
  attr_accessor :base_path    # The root of the application. Used for determining where log files and PID files should go.
  
  # configure the singleton with some defaults
  def initialize(params = {})
    # @pid = nil
    if defined?(Rails.root)
      @base_path = Rails.root
    else
      @base_path = "."
    end
    @logger = Logger.new("#{@base_path}/tmp/jettywrapper-debug.log")
    @logger.debug 'Initializing jettywrapper'
  end
  
  class << self
    
    # Set the jetty parameters. It accepts a Hash of symbols. 
    # @param [Hash<Symbol>] params
    # @param [Symbol] :jetty_home Required. Where is jetty located? 
    # @param [Symbol] :jetty_port What port should jetty start on? Default is 8888
    # @param [Symbol] :startup_wait After jetty starts, how long to wait before running tests? If you don't let jetty start all the way before running the tests, they'll fail because they can't reach jetty.
    # @param [Symbol] :solr_home Where is solr? Default is jetty_home/solr
    # @param [Symbol] :fedora_home Where is fedora? Default is jetty_home/fedora/default
    # @param [Symbol] :quiet Keep quiet about jetty output? Default is true. 
    def configure(params = {})
      hydra_server = self.instance
      hydra_server.quiet = params[:quiet].nil? ? true : params[:quiet]
      if defined?(Rails.root)
       base_path = Rails.root
      else
       raise "You must set either RAILS_ROOT or :jetty_home so I know where jetty is" unless params[:jetty_home]
      end
      hydra_server.jetty_home = params[:jetty_home] || File.expand_path(File.join(base_path, 'jetty'))
      hydra_server.solr_home = params[:solr_home]  || File.join( hydra_server.jetty_home, "solr")
      hydra_server.fedora_home = params[:fedora_home] || File.join( hydra_server.jetty_home, "fedora","default")
      hydra_server.port = params[:jetty_port] || 8888
      hydra_server.startup_wait = params[:startup_wait] || 5
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
    def wrap(params = {})
      error = false
      jetty_server = self.instance
      jetty_server.quiet = params[:quiet] || true
      jetty_server.jetty_home = params[:jetty_home]
      jetty_server.solr_home = params[:solr_home]
      jetty_server.port = params[:jetty_port] || 8888
      jetty_server.startup_wait = params[:startup_wait] || 5
      jetty_server.fedora_home = params[:fedora_home] || File.join( jetty_server.jetty_home, "fedora","default")

      begin
        # puts "starting jetty on #{RUBY_PLATFORM}"
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
    #    Jettywrapper.start_with_params(:jetty_home => '/path/to/jetty', :jetty_port => '8983')
    def start_with_params(params)
       Jettywrapper.configure(params)
       Jettywrapper.instance.start
       return Jettywrapper.instance
    end
    
    # Convenience method for configuring and starting jetty with one command. Note
    # that for stopping, only the :jetty_home value is required (including other values won't 
    # hurt anything, though). 
    # @param [Hash] params: The jetty_home to use for stopping jetty
    # @example 
    #    Jettywrapper.stop_with_params(:jetty_home => '/path/to/jetty')
    def stop_with_params(params)
       Jettywrapper.configure(params)
       Jettywrapper.instance.stop
       return Jettywrapper.instance
    end
    
    end #end of class << self
    
        
   # What command is being run to invoke jetty? 
   def jetty_command
     "java -Djetty.port=#{@port} -Dsolr.solr.home=#{@solr_home} -Dfedora.home=#{@fedora_home} -jar start.jar"
   end
   
   # Start the jetty server. Check the pid file to see if it is running already, 
   # and stop it if so. After you start jetty, write the PID to a file. 
   def start
     @logger.debug "Starting jetty with these values: "
     @logger.debug "jetty_home: #{@jetty_home}"
     @logger.debug "solr_home: #{@solr_home}"
     @logger.debug "fedora_home: #{@fedora_home}"
     @logger.debug "jetty_command: #{jetty_command}"
          
     if pid
       begin
         Process.kill(0,pid)
         raise("Server is already running with PID #{pid}")
       rescue Errno::ESRCH
         @logger.warn "Removing stale PID file at #{pid_path}"
         File.delete(pid_path)
       end
     end
     Dir.chdir(@jetty_home) do
       self.send "#{platform}_process".to_sym
     end
     File.makedirs(pid_dir) unless File.directory?(pid_dir)
     begin
       f = File.new(pid_path,  "w")
     rescue Errno::ENOENT, Errno::EACCES
       f = File.new(File.join(@base_path,'tmp',pid_file),"w")
     end
     f.puts "#{@pid}"
     f.close
     @logger.debug "Wrote pid file to #{pid_path} with value #{@pid}"
   end
 
   def stop
     @logger.warn "stopping jetty... "
     if pid
       begin
         self.send "#{platform}_stop".to_sym
       rescue Errno::ESRCH
         @logger.warn "Removing stale PID file at #{pid_path}"
       end
       FileUtils.rm(pid_path)
     end
   end
 
   def win_process
     @pid = Process.create(
           :app_name         => jetty_command,
           :creation_flags   => Process::DETACHED_PROCESS,
           :process_inherit  => false,
           :thread_inherit   => true,
           :cwd              => "#{@jetty_home}"
        ).process_id
   end

   def platform
     case RUBY_PLATFORM
     when /mswin32/
       return 'win'
     else
       return 'nix'
     end
   end

   def nix_process
     @pid = fork do
       # STDERR.close if @quiet
       exec jetty_command
     end
   end

   # stop jetty the windows way
   def win_stop
     Process.kill(1, pid)
   end

   # stop jetty the *nix way
   def nix_stop
     @logger.debug "Killing process #{pid}"
     Process.kill('TERM',pid)
   end

   def pid_path
     File.join(pid_dir, pid_file)
   end

   # The file where the process ID will be written
   def pid_file
     @pid_file || jetty_home_to_pid_file
   end
   
   # Take the @jetty_home value and transform it into a legal filename
   # @return [String] the name of the pid_file
   # @example
   #    /usr/local/jetty1 => _usr_local_jetty1.pid
   def jetty_home_to_pid_file
    @jetty_home.gsub(/\//,'_') << ".pid"
   end

   # The directory where the pid_file will be written
   def pid_dir
     File.expand_path(@pid_dir || File.join(@base_path,'tmp','pids'))
   end
   
   # Check to see if there is a pid file already
   # @return true if the file exists, otherwise false
   def pid_file?
      return true if File.exist?(pid_path)
      false
   end

   def pid
      @pid || File.open( pid_path ) { |f| return f.gets.to_i } if File.exist?(pid_path)
   end
   
end