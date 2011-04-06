module Hydra
  module Testing
    class TestServer

      require 'singleton'
      include Singleton
      attr_accessor :port, :jetty_home, :solr_home, :quiet, :fedora_home, :startup_wait      
      
      # configure the singleton with some defaults
      def initialize
        @pid = nil
      end
      
      class << self
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
        
        def wrap(params = {})
          error = false
          jetty_server = self.instance
          jetty_server.quiet = params[:quiet] || true
          jetty_server.jetty_home = params[:jetty_home]
          jetty_server.solr_home = params[:solr_home]
          jetty_server.port = params[:jetty_port] || 8888
          jetty_server.startup_wait = params[:startup_wait] || 5
          
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
      
      def jetty_command
        "java -Djetty.port=#{@port} -Dsolr.solr.home=#{@solr_home} -jar start.jar"
      end

      def start
        puts "jetty_home: #{@jetty_home}"
        puts "solr_home: #{@solr_home}"
        puts "jetty_command: #{jetty_command}"
        platform_specific_start
      end

      def stop
        platform_specific_stop
      end

      if RUBY_PLATFORM =~ /mswin32/
        require 'win32/process'

        # start the solr server
        def platform_specific_start
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

        # stop a running solr server
        def platform_specific_stop
          Process.kill(1, @pid)
          Process.wait
        end
      else # Not Windows

        def jruby_raise_error?
          raise 'JRuby requires that you start solr manually, then run "rake spec" or "rake features"' if defined?(JRUBY_VERSION)
        end

        # start the solr server
        def platform_specific_start

          jruby_raise_error?

          puts self.inspect
          Dir.chdir(@jetty_home) do
            @pid = fork do
              STDERR.close if @quiet
              exec jetty_command
            end
          end
        end

        # stop a running solr server
        def platform_specific_stop
          jruby_raise_error?
          Process.kill('TERM', @pid)
          Process.wait
        end
      end

    end
  end
end
