require File.join(File.dirname(__FILE__), "/../spec_helper")
require File.join(File.dirname(__FILE__), "/../../lib/hydra-testing")

module Hydra
  module Testing
    describe TestServer do
      
      before(:all) do
        RAILS_ROOT = "/path/to/rails/root"
        @jetty_params = {
          :quiet => false,
          :jetty_home => "/path/to/jetty",
          :jetty_port => 8888,
          :solr_home => '/path/to/solr',
          :fedora_home => '/path/to/fedora'
        }
      end
      
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
      end

      it "raises an error when called without a :jetty_home value" do
          lambda { ts = Hydra::Testing::TestServer.configure }.should raise_exception
          
      end

      it "should override nil params with defaults" do
        jetty_params = {
          :quiet => nil,
          :jetty_home => '/path/to/jetty',
          :jetty_port => nil,
          :solr_home => nil,
          :fedora_home => nil
        }

        ts = Hydra::Testing::TestServer.configure(jetty_params) 
        ts.quiet.should == true
        ts.jetty_home.should == "/path/to/jetty"
        ts.port.should == 8888
        ts.solr_home.should == File.join(ts.jetty_home, "solr")
        ts.fedora_home.should == File.join(ts.jetty_home, "fedora","default")
      end
      
    end
  end
end