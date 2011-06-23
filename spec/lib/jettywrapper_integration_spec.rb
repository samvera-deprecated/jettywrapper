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
        sleep 30 # give jetty time to start
      
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
        sleep 30
        ts.logger.debug "Jetty started from rspec at #{ts.pid}"
        response = Net::HTTP.get_response(URI.parse("http://localhost:8888/solr/admin/"))
        response.code.should eql("200")
        lambda { ts.start }.should raise_exception(/Server is already running/)
        ts.stop
      end
      
      it "can start multiple copies of jetty, as long as they have different jetty_homes" do
        jetty1_params = {
          :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../../jetty1"),
          :jetty_port => '8983'
        }
        jetty2_params = {
          :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../../jetty2"),
          :jetty_port => '8984'
        }
        
        # Ensure nothing is running when we start
        Jettywrapper.stop_with_params(jetty1_params) 
        Jettywrapper.stop_with_params(jetty2_params)
        
        # Spin up two copies of jetty, with different jetty home values and on different ports
        Jettywrapper.start_with_params(jetty1_params) 
        Jettywrapper.start_with_params(jetty2_params) 
        
        # Ensure both are viable
        sleep 30
        response1 = Net::HTTP.get_response(URI.parse("http://localhost:8983/solr/admin/"))
        response1.code.should eql("200")
        response2 = Net::HTTP.get_response(URI.parse("http://localhost:8984/solr/admin/"))
        response2.code.should eql("200")
        
        # Shut them both down
        Jettywrapper.stop_with_params(jetty1_params) 
        Jettywrapper.stop_with_params(jetty2_params)
      end
      
    end
    
  end
end