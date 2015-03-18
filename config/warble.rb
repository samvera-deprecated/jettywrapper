# Warbler web application assembly configuration file
Warbler::Config.new do |config|
  config.features = ['compiled']

  config.webxml.rails.env='development'

  # Name of the archive (without the extension). Defaults to the basename
  # of the project directory.
  config.jar_name = ENV['WAR_FILENAME'] ||= "demoname"

  # File extension for the archive. Defaults to either 'jar' or 'war'.
  config.jar_extension = "war"

  # Destionation for the created archive. Defaults to project's root directory.
  config.autodeploy_dir = "dist/"
end
