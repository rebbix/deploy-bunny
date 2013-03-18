Capistrano::Configuration.instance(:must_exist).load do
  namespace :crontab do
    task :update, :roles => crontab_roles do
      on_rollback do
        if previous_release
          app_env "#{bundle_exec cd: previous_release} whenever --update-crontab #{application}"
        else
          app_env "#{bundle_exec} whenever --clear-crontab #{application}"
        end
      end

      app_env "#{bundle_exec} whenever --update-crontab #{application}"
    end

    task :clear, :roles => crontab_roles do
      app_env "#{bundle_exec} whenever --clear-crontab #{application}"
    end
  end
end

