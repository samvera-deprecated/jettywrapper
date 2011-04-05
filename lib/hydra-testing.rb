module Hydra
  module Testing
    class TestServer

      require 'singleton'
      include Singleton
      attr_accessor :port, :jetty_home, :solr_home, :quiet, :fedora_home

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
          return hydra_server
        end
        
        def wrap(params = {})
          error = false
          hydra_server = self.configure(params)
          begin
            puts "starting Hydra jetty server on #{RUBY_PLATFORM}"
            hydra_server.start
            sleep params[:startup_wait] || 5
            yield
          rescue
            error = true
          ensure
            puts "stopping Hydra jetty server"
            hydra_server.stop
          end

          return error
        end
        
      end #end of class << self

    end
  end
end
