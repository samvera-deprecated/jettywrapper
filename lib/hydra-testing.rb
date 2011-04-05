module Hydra
  module Testing
    class TestServer

      require 'singleton'
      include Singleton
      attr_accessor :port, :jetty_home, :solr_home, :quiet

      # configure the singleton with some defaults
      def initialize
        @pid = nil
      end

    end
  end
end
