require 'rake'
require 'bundler'
require 'spec/rake/spectask'
require 'yard'

Bundler::GemHelper.install_tasks
Dir.glob('tasks/*.rake').each { |r| import r }


begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
  spec.rcov_opts = %w{--exclude spec\/*,gems\/*,ruby\/* --aggregate coverage.data}
end

task :clean do
  puts 'Cleaning old coverage.data'
  FileUtils.rm('coverage.data') if(File.exists? 'coverage.data')
end

# Use yard to build docs
begin
  require 'yard'
  require 'yard/rake/yardoc_task'
  project_root = File.expand_path(File.dirname(__FILE__))
  doc_destination = File.join(project_root, 'doc')

  YARD::Rake::YardocTask.new(:doc) do |yt|
    yt.files   = Dir.glob(File.join(project_root, 'lib', '**', '*.rb')) + 
                 [ File.join(project_root, 'README.textile') ]
    yt.options = ['--output-dir', doc_destination, '--readme', 'README.textile']
  end
rescue LoadError
  desc "Generate YARD Documentation"
  task :doc do
    abort "Please install the YARD gem to generate rdoc."
  end
end

task :default => [:rcov, :doc]