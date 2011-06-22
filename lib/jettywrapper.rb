# Jettywrapper is a Singleton class, so you can only create one jetty instance at a time.

class Jettywrapper
  
  require 'singleton'
  include Singleton
  
  attr_accessor :pid          # If Jettywrapper is running, what pid is it running as? 
  attr_accessor :port         # What port should jetty start on? Default is 8888
  attr_accessor :jetty_home   # Where is jetty located? 
  attr_accessor :startup_wait # After jetty starts, how long to wait until starting the tests? 
  attr_accessor :quiet        # Keep quiet about jetty output?
  attr_accessor :solr_home    # Where is solr located? Default is jetty_home/solr
  attr_accessor :fedora_home  # Where is fedora located? Default is jetty_home/fedora
  
  # configure the singleton with some defaults
  # def initialize
  #   @pid = nil
  # end
  
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
     
   end #end of class << self
   
   # What command is being run to invoke jetty? 
   def jetty_command
     "java -Djetty.port=#{@port} -Dsolr.solr.home=#{@solr_home} -Dfedora.home=#{@fedora_home} -jar start.jar"
   end
   
   def start
     puts "jetty_home: #{@jetty_home}"
     puts "solr_home: #{@solr_home}"
     puts "fedora_home: #{@fedora_home}"
     puts "jetty_command: #{jetty_command}"
     platform_specific_start
   end
   
   def stop
     platform_specific_stop
   end
   
   if RUBY_PLATFORM =~ /mswin32/
     require 'win32/process'
   
     # start jetty for windows
     def platform_specific_start
       puts "Starting Jetty on windows"
       Dir.chdir(@jetty_home) do
         @pid = Process.create(
               :app_name         => jetty_command,
               :creation_flags   => Process::DETACHED_PROCESS,
               :process_inherit  => false,
               :thread_inherit   => true,
               :cwd              => "#{@jetty_home}"
            ).process_id
       end
     end
   
     # stop jetty for windows
     def platform_specific_stop
       Process.kill(1, @pid)
       Process.wait
     end
   else # Not Windows
   
     def jruby_raise_error?
       raise 'JRuby requires that you start solr manually, then run "rake spec" or "rake features"' if defined?(JRUBY_VERSION)
     end
   
     # start jetty for *nix
     def platform_specific_start
       jruby_raise_error?   
       Dir.chdir(@jetty_home) do
         @pid = fork do
           STDERR.close if @quiet
           exec jetty_command
         end
       end
     end
   
     # stop jetty for *nix
     def platform_specific_stop
       jruby_raise_error?
       Process.kill('TERM', @pid)
       Process.wait
     end
  end

end