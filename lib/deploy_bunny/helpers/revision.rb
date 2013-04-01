Capistrano::Configuration.instance(:must_exist).load do
  if respond_to? :log_formatter
    log_formatter([
      { :match => /^revision: /, :color => :blue, :priority => 10 }
    ])
  end

  namespace :helpers do
    desc <<-DESC
      Get revision of deployed code.
    DESC
    task :revision do
      if current_release
        logger.info "revision: #{latest_revision}"
      end
    end
  end
end
