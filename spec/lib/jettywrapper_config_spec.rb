require 'spec_helper'
require 'jettywrapper/config'


def init()
  @jetty_params = {
    :port         => 2222,
    :startup_wait => 30,
    :quiet        => false,
    :jetty_home   => "/path/to/jetty",
    :solr_home    => "/path/to/solr",
    :java_opts    => ["-Xmx256m"],
    :jetty_opts   => ["/path/to/jetty_xml", "/path/to/other_jetty_xml"],
    :hydra_jetty_version => 'v0.99.2',
    :url          => 'http://fake.com/path/file.ext',
    :tmp_dir      => 'othertmp',
    :zip_file     => '/tmp/new_jetty.zip',
  }
end

RSpec.describe Jettywrapper::Config do
  before(:all) do
    init
  end

  context "default" do
    it "should have default values" do
      expect(subject.port        ).to eq(8888)
      expect(subject.startup_wait).to eq(5)
      expect(subject.quiet       ).to be(true)
      expect(subject.java_opts   ).to eq([])
      expect(subject.jetty_opts  ).to eq([])
      expect(subject.hydra_jetty_version).to eq('v7.0.0')
      expect(subject.url         ).to eq('https://github.com/projecthydra/hydra-jetty/archive/v7.0.0.zip')
      puts subject.inspect
    end
    it "should accept assigments" do
      @jetty_params.each { |k,v| subject.send("#{k.to_s}=", v) }
      @jetty_params.each { |k,v|
        expect(subject.send(k.to_s)).to eq(v)
      }
    end
    it "hydra_jetty_version= should invalidate URL" do
      subject.url = url = 'https://foobar.com/whatev.zip'
      expect(subject.url).to eq(url)
      subject.hydra_jetty_version = @jetty_params[:hydra_jetty_version]
      expect(subject.hydra_jetty_version).to eq(@jetty_params[:hydra_jetty_version])
      expect(subject.url).to eq("https://github.com/projecthydra/hydra-jetty/archive/#{@jetty_params[:hydra_jetty_version]}.zip")
    end
    it "should treat port and jetty_port the same" do
      subject.port = 5555
      expect(subject.jetty_port).to eq(5555)
      expect(subject.port      ).to eq(5555)
      ## including in constructor
      other = Jettywrapper::Config.new({:jetty_port => 7777})
      expect(other.jetty_port).to eq(7777)
      expect(other.port      ).to eq(7777)
    end
  end
end

RSpec.describe Jettywrapper::Config, "with args" do
  before(:all) do
    init
  end
  subject { Jettywrapper::Config.new(@jetty_params) }
  context "with arguments" do
    it "should retain supplied arguments" do
      @jetty_params.each { |k,v|
        expect(subject.send(k.to_s)).to eq(v)
      }
    end
  end
end
