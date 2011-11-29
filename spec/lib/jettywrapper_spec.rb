require 'spec_helper'
require 'rubygems'

  describe Jettywrapper do
    
    # JETTY1 = 
    
    before(:all) do
      @jetty_params = {
        :quiet => false,
        :jetty_home => "/path/to/jetty",
        :jetty_port => 8888,
        :solr_home => "/path/to/solr",
        :startup_wait => 0,
        :java_opts => ["-Xmx256mb"]
      }
    end

    context "config" do
      it "loads the application jetty.yml first" do
        YAML.expects(:load_file).with('./config/jetty.yml').once.returns({})
        config = Jettywrapper.load_config
      end

      it "falls back on the distributed jetty.yml" do
        fallback_seq = sequence('fallback sequence')
        YAML.expects(:load_file).in_sequence(fallback_seq).with('./config/jetty.yml').raises(Exception)
        YAML.expects(:load_file).in_sequence(fallback_seq).with { |value| value =~ /jetty.yml/ }.returns({})
        config = Jettywrapper.load_config
      end

      it "supports per-environment configuration" do
        ENV['environment'] = 'test'
        YAML.expects(:load_file).with('./config/jetty.yml').once.returns({:test => {:a => 2 }, :default => { :a => 1 }})
        config = Jettywrapper.load_config
        config[:a].should == 2
      end

      it "falls back on a 'default' environment configuration" do
        ENV['environment'] = 'test'
        YAML.expects(:load_file).with('./config/jetty.yml').once.returns({:default => { :a => 1 }})
        config = Jettywrapper.load_config
        config[:a].should == 1
      end
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
          :startup_wait => nil
        }

        ts = Jettywrapper.configure(jetty_params) 
        ts.quiet.should == true
        ts.jetty_home.should == "/path/to/jetty"
        ts.port.should == 8888
        ts.solr_home.should == File.join(ts.jetty_home, "solr")
        ts.startup_wait.should == 5
      end
      
      it "passes all the expected values to jetty during startup" do
        ts = Jettywrapper.configure(@jetty_params) 
        command = ts.jetty_command
        command.should include("-Dsolr.solr.home=#{@jetty_params[:solr_home]}")
        command.should include("-Djetty.port=#{@jetty_params[:jetty_port]}")
        command.should include("-Xmx256mb")
      end

      it "escapes the :solr_home parameter" do
        ts = Jettywrapper.configure(@jetty_params.merge(:solr_home => '/path with spaces/to/solr'))
        command = ts.jetty_command
        command.should include("-Dsolr.solr.home=/path\\ with\\ spaces/to/solr")
      end
      
      it "has a pid if it has been started" do
        jetty_params = {
          :jetty_home => '/tmp'
        }
        ts = Jettywrapper.configure(jetty_params) 
        Jettywrapper.any_instance.stubs(:process).returns(stub('proc', :start => nil, :pid=>5454))
        ts.stop
        ts.start
        ts.pid.should eql(5454)
        ts.stop
      end
      
      it "can pass params to a start method" do
        jetty_params = {
          :jetty_home => '/tmp', :jetty_port => 8777
        }
        ts = Jettywrapper.configure(jetty_params) 
        ts.stop
        Jettywrapper.any_instance.stubs(:process).returns(stub('proc', :start => nil, :pid=>2323))
        swp = Jettywrapper.start(jetty_params)
        swp.pid.should eql(2323)
        swp.pid_file.should eql("_tmp.pid")
        swp.stop
      end
      
      it "checks to see if its pid files are stale" do
        @pending
      end
      
      # return true if it's running, otherwise return false
      it "can get the status for a given jetty instance" do
        # Don't actually start jetty, just fake it
        Jettywrapper.any_instance.stubs(:process).returns(stub('proc', :start => nil, :pid=>12345))
        
        jetty_params = {
          :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../../jetty")
        }
        Jettywrapper.stop(jetty_params)
        Jettywrapper.is_jetty_running?(jetty_params).should eql(false)
        Jettywrapper.start(jetty_params)
        Jettywrapper.is_jetty_running?(jetty_params).should eql(true)
        Jettywrapper.stop(jetty_params)
      end
      
      it "can get the pid for a given jetty instance" do
        # Don't actually start jetty, just fake it
        Jettywrapper.any_instance.stubs(:process).returns(stub('proc', :start => nil, :pid=>54321))
        jetty_params = {
          :jetty_home => File.expand_path("#{File.dirname(__FILE__)}/../../jetty")
        }
        Jettywrapper.stop(jetty_params)
        Jettywrapper.pid(jetty_params).should eql(nil)
        Jettywrapper.start(jetty_params)
        Jettywrapper.pid(jetty_params).should eql(54321)
        Jettywrapper.stop(jetty_params)
      end
      
      it "can pass params to a stop method" do
        jetty_params = {
          :jetty_home => '/tmp', :jetty_port => 8777
        }
        Jettywrapper.any_instance.stubs(:process).returns(stub('proc', :start => nil, :pid=>2323))
        swp = Jettywrapper.start(jetty_params)
        (File.file? swp.pid_path).should eql(true)
        
        swp = Jettywrapper.stop(jetty_params)
        (File.file? swp.pid_path).should eql(false)
      end
      
      it "knows what its pid file should be called" do
        ts = Jettywrapper.configure(@jetty_params) 
        ts.pid_file.should eql("_path_to_jetty.pid")
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
        Jettywrapper.any_instance.stubs(:process).returns(stub('proc', :start => nil, :pid=>2222))
        ts.stop
        ts.pid_file?.should eql(false)
        ts.start
        ts.pid.should eql(2222)
        ts.pid_file?.should eql(true)
        pid_from_file = File.open( ts.pid_path ) { |f| f.gets.to_i }
        pid_from_file.should eql(2222)
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
          ts.quiet.should == @jetty_params[:quiet]
          ts.jetty_home.should == "/path/to/jetty"
          ts.port.should == 8888
          ts.solr_home.should == "/path/to/solr"
          ts.startup_wait.should == 0     
        end
        error.should eql(false)
      end
      
      it "captures any errors produced" do
        Jettywrapper.any_instance.stubs(:start).returns(true)
        Jettywrapper.any_instance.stubs(:stop).returns(true)
        error = Jettywrapper.wrap(@jetty_params) do 
          raise "this is an expected error message"
        end
        error.class.should eql(RuntimeError)
        error.message.should eql("this is an expected error message")
      end
      
    end # end of wrapping context

    context "quiet mode", :quiet => true do
      it "inherits the current stderr/stdout in 'loud' mode" do
        ts = Jettywrapper.configure(@jetty_params.merge(:quiet => false))
        process = ts.process
        process.io.stderr.should == $stderr
        process.io.stdout.should == $stdout
      end

      it "redirect stderr/stdout to a log file in quiet mode" do
        ts = Jettywrapper.configure(@jetty_params.merge(:quiet => true))
        process = ts.process
        process.io.stderr.should_not == $stderr
        process.io.stdout.should_not == $stdout
      end
    end
  end
