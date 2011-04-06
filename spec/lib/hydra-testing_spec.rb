require File.join(File.dirname(__FILE__), "/../spec_helper")
require File.join(File.dirname(__FILE__), "/../../lib/hydra-testing")

module Hydra
  module Testing
    describe TestServer do
      
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
          ts = Hydra::Testing::TestServer.instance
          ts.class.should eql(Hydra::Testing::TestServer)
        end

        it "can be configured with a params hash" do
          ts = Hydra::Testing::TestServer.configure(@jetty_params) 
          ts.quiet.should == false
          ts.jetty_home.should == "/path/to/jetty"
          ts.port.should == 8888
          ts.solr_home.should == '/path/to/solr'
          ts.fedora_home.should == '/path/to/fedora'
          ts.startup_wait.should == 0
        end

        # passing in a hash is no longer optional
        it "raises an error when called without a :jetty_home value" do
            lambda { ts = Hydra::Testing::TestServer.configure }.should raise_exception
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

          ts = Hydra::Testing::TestServer.configure(jetty_params) 
          ts.quiet.should == true
          ts.jetty_home.should == "/path/to/jetty"
          ts.port.should == 8888
          ts.solr_home.should == File.join(ts.jetty_home, "solr")
          ts.fedora_home.should == File.join(ts.jetty_home, "fedora","default")
          ts.startup_wait.should == 5
        end
      end # end of instantiation context
      
      context "wrapping a task" do
        it "wraps another method" do
          Hydra::Testing::TestServer.any_instance.stubs(:start).returns(true)
          Hydra::Testing::TestServer.any_instance.stubs(:stop).returns(true)
          error = Hydra::Testing::TestServer.wrap(@jetty_params) do            
          end
          error.should eql(false)
        end
        
        it "configures itself correctly when invoked via the wrap method" do
          Hydra::Testing::TestServer.any_instance.stubs(:start).returns(true)
          Hydra::Testing::TestServer.any_instance.stubs(:stop).returns(true)
          error = Hydra::Testing::TestServer.wrap(@jetty_params) do 
            ts = Hydra::Testing::TestServer.instance 
            ts.quiet.should == true
            ts.jetty_home.should == "/path/to/jetty"
            ts.port.should == 8888
            ts.solr_home.should == "/path/to/solr"
            ts.fedora_home.should == "/path/to/fedora"
            ts.startup_wait.should == 0     
          end
          error.should eql(false)
        end
        
      end
      
    end
  end
end