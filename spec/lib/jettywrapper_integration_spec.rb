require File.join(File.dirname(__FILE__), "/../spec_helper")
require File.join(File.dirname(__FILE__), "/../../lib/jettywrapper")
require 'rubygems'
require 'ruby-debug'
require 'uri'
require 'net/http'

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
        Jettywrapper.stop(jetty1_params) 
        Jettywrapper.stop(jetty2_params)
        
        # Spin up two copies of jetty, with different jetty home values and on different ports
        Jettywrapper.start(jetty1_params) 
        pid1 = Jettywrapper.pid(jetty1_params)
        Jettywrapper.start(jetty2_params) 
        pid2 = Jettywrapper.pid(jetty2_params)
        
        # Ensure both are viable
        sleep 40
        response1 = Net::HTTP.get_response(URI.parse("http://localhost:8983/solr/admin/"))
        response1.code.should eql("200")
        response2 = Net::HTTP.get_response(URI.parse("http://localhost:8984/solr/admin/"))
        response2.code.should eql("200")
        
        # Shut them both down
        Jettywrapper.pid(jetty1_params).should eql(pid1)
        Jettywrapper.stop(jetty1_params)
        Jettywrapper.is_pid_running?(pid1).should eql(false)
        Jettywrapper.pid(jetty2_params).should eql(pid2)
        Jettywrapper.stop(jetty2_params)
        Jettywrapper.is_pid_running?(pid2).should eql(false)
      end
      
      it "raises an error if you try to start a jetty that is already running" do
        jetty_params = {
          :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../../jetty1"),
          :jetty_port => '8983'
        }
        ts = Jettywrapper.configure(jetty_params) 
        ts.stop
        ts.pid_file?.should eql(false)
        ts.start
        sleep 30
        lambda{ ts.start }.should raise_exception
        ts.stop
      end
      
      it "can check to see whether a port is already in use" do
        params = {
          :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../../jetty1"),
          :jetty_port => '9999'
        }
        Jettywrapper.stop(params) 
        sleep 10
        Jettywrapper.is_port_in_use?(params[:jetty_port]).should eql(false)
        Jettywrapper.start(params) 
        sleep 30
        Jettywrapper.is_port_in_use?(params[:jetty_port]).should eql(true)
        Jettywrapper.stop(params) 
      end
      
      # Not ready for this yet
      # it "won't start if there is a port conflict" do
      #   jetty1_params = {
      #     :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../../jetty1"),
      #     :jetty_port => '8983'
      #   }
      #   jetty2_params = {
      #     :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../../jetty2"),
      #     :jetty_port => '8983'
      #   }
      #   # Ensure nothing is running when we start
      #   Jettywrapper.stop(jetty1_params) 
      #   Jettywrapper.stop(jetty2_params)
      #   
      #   # Spin up two copies of jetty, with different jetty home values but the same port
      #   Jettywrapper.start(jetty1_params) 
      #   lambda{ Jettywrapper.start(jetty2_params) }.should raise_exception
      #   
      #   # Shut them both down
      #   Jettywrapper.stop(jetty1_params) 
      #   Jettywrapper.stop(jetty2_params)
      # end
      
    end
    
  end
end