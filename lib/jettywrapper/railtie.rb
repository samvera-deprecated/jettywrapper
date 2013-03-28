class Jettywrapper
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/jettywrapper.rake'
    end
  end
end
