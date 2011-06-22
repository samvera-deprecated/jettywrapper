require File.join(File.dirname(__FILE__), "/../spec_helper")
require File.join(File.dirname(__FILE__), "/../../lib/jettywrapper")
require 'rubygems'
require 'ruby-debug'
require 'uri'

module Hydra
  describe Jettywrapper do    
    context "integration" do
      before(:all) do
        $stderr.reopen("/dev/null", "w")
      end
      
      it "starts" do
        
        jetty_params = {
          :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../../jetty1")
        
        }
        Jettywrapper.configure(jetty_params) 
        ts = Jettywrapper.instance
        ts.logger.debug "Stopping jetty from rspec."
        ts.stop
        ts.start      
        ts.logger.debug "Jetty started from rspec at #{ts.pid}"
        pid_from_file = File.open( ts.pid_path ) { |f| f.gets.to_i }
        ts.pid.should eql(pid_from_file)
        sleep 15 # give jetty time to start
      
        # Can we connect to solr?
        require 'net/http' 
        response = Net::HTTP.get_response(URI.parse("http://localhost:8888/solr/admin/"))
        response.code.should eql("200")
        ts.stop
      
      end
      
      it "won't start if it's already running" do
        jetty_params = {
          :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../../jetty1")
        
        }
        Jettywrapper.configure(jetty_params) 
        ts = Jettywrapper.instance
        ts.logger.debug "Stopping jetty from rspec."
        ts.stop
        ts.start
        sleep 15
        ts.logger.debug "Jetty started from rspec at #{ts.pid}"
        response = Net::HTTP.get_response(URI.parse("http://localhost:8888/solr/admin/"))
        response.code.should eql("200")
        lambda { ts.start }.should raise_exception(/Server is already running/)
        ts.stop
      end
      
    end
    
  end
end