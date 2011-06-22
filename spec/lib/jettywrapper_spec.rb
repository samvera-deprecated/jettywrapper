require File.join(File.dirname(__FILE__), "/../spec_helper")
require File.join(File.dirname(__FILE__), "/../../lib/jettywrapper")
require 'rubygems'
require 'ruby-debug'

module Hydra
  describe Jettywrapper do
    
    before(:all) do
      @jetty_params = {
        :quiet => false,
        :jetty_home => "/path/to/jetty",
        :jetty_port => 8888,
        :solr_home => "/path/to/solr",
        :fedora_home => "/path/to/fedora",
        :startup_wait => 0
      }
    end
    
    context "instantiation" do
      it "can be instantiated" do
        ts = Jettywrapper.instance
        ts.class.should eql(Jettywrapper)
      end

      it "can be configured with a params hash" do
        ts = Jettywrapper.configure(@jetty_params) 
        ts.quiet.should == false
        ts.jetty_home.should == "/path/to/jetty"
        ts.port.should == 8888
        ts.solr_home.should == '/path/to/solr'
        ts.fedora_home.should == '/path/to/fedora'
        ts.startup_wait.should == 0
      end

      # passing in a hash is no longer optional
      it "raises an error when called without a :jetty_home value" do
          lambda { ts = Jettywrapper.configure }.should raise_exception
      end

      it "should override nil params with defaults" do
        jetty_params = {
          :quiet => nil,
          :jetty_home => '/path/to/jetty',
          :jetty_port => nil,
          :solr_home => nil,
          :fedora_home => nil,
          :startup_wait => nil
        }

        ts = Jettywrapper.configure(jetty_params) 
        ts.quiet.should == true
        ts.jetty_home.should == "/path/to/jetty"
        ts.port.should == 8888
        ts.solr_home.should == File.join(ts.jetty_home, "solr")
        ts.fedora_home.should == File.join(ts.jetty_home, "fedora","default")
        ts.startup_wait.should == 5
      end
      
      it "passes all the expected values to jetty during startup" do
        ts = Jettywrapper.configure(@jetty_params) 
        command = ts.jetty_command
        command.should include("-Dfedora.home=#{@jetty_params[:fedora_home]}")
        command.should include("-Dsolr.solr.home=#{@jetty_params[:solr_home]}")
        command.should include("-Djetty.port=#{@jetty_params[:jetty_port]}")
        
      end
      
      it "has a pid if it has been started" do
        jetty_params = {
          :jetty_home => '/tmp'
        }
        ts = Jettywrapper.configure(jetty_params) 
        Jettywrapper.any_instance.stubs(:fork).returns(5454)
        ts.start
        ts.pid.should eql(5454)
      end
      
      it "knows what its pid file should be called" do
        ts = Jettywrapper.configure(@jetty_params) 
        ts.pid_file.should eql("hydra-jetty.pid")
      end
      
      it "knows where its pid file should be written" do
        ts = Jettywrapper.configure(@jetty_params) 
        ts.pid_dir.should eql(File.expand_path("#{ts.base_path}/tmp/pids"))
      end
      
      it "writes a pid to a file when it is started" do
        jetty_params = {
          :jetty_home => '/tmp'
        }
        ts = Jettywrapper.configure(jetty_params) 
        Jettywrapper.any_instance.stubs(:fork).returns(2222)
        FileUtils.rm(ts.pid_path)
        ts.pid_file?.should eql(false)
        ts.start
        ts.pid.should eql(2222)
        ts.pid_file?.should eql(true)
        pid_from_file = File.open( ts.pid_path ) { |f| f.gets.to_i }
        pid_from_file.should eql(2222)
      end
      
      it "checks to see if jetty is running already before it starts" do
        jetty_params = {
          :jetty_home => '/tmp'
        }
        ts = Jettywrapper.configure(jetty_params) 
        Jettywrapper.any_instance.stubs(:fork).returns(3333)
        FileUtils.rm(ts.pid_path)
        ts.pid_file?.should eql(false)
        ts.start
        ts.pid.should eql(3333)
        Jettywrapper.any_instance.stubs(:fork).returns(4444)
        ts.start
        ts.pid.should eql(4444)
      end
      
    end # end of instantiation context
    
    context "logging" do
      it "has a logger" do
        ts = Jettywrapper.configure(@jetty_params) 
        ts.logger.should be_kind_of(Logger)
      end
      
    end # end of logging context 
    
    context "wrapping a task" do
      it "wraps another method" do
        Jettywrapper.any_instance.stubs(:start).returns(true)
        Jettywrapper.any_instance.stubs(:stop).returns(true)
        error = Jettywrapper.wrap(@jetty_params) do            
        end
        error.should eql(false)
      end
      
      it "configures itself correctly when invoked via the wrap method" do
        Jettywrapper.any_instance.stubs(:start).returns(true)
        Jettywrapper.any_instance.stubs(:stop).returns(true)
        error = Jettywrapper.wrap(@jetty_params) do 
          ts = Jettywrapper.instance 
          ts.quiet.should == true
          ts.jetty_home.should == "/path/to/jetty"
          ts.port.should == 8888
          ts.solr_home.should == "/path/to/solr"
          ts.fedora_home.should == "/path/to/fedora"
          ts.startup_wait.should == 0     
        end
        error.should eql(false)
      end
      
      it "captures any errors produced" do
        Jettywrapper.any_instance.stubs(:start).returns(true)
        Jettywrapper.any_instance.stubs(:stop).returns(true)
        error = Jettywrapper.wrap(@jetty_params) do 
          raise "foo"
        end
        error.class.should eql(RuntimeError)
        error.message.should eql("foo")
      end
      
    end # end of wrapping context
  end
end