Capistrano::Configuration.instance(:must_exist).load do
  _cset(:crontab_roles)    {[:cron]}
  _cset(:crontab_provider) { :whenever }

  if respond_to? :log_formatter
    log_formatter([
      { :match => /^crontab:/,           :color => :cyan, :priority => 10 },
      { :match => /^crontab: restoring/, :color => :red,  :priority => 15 }
    ])
  end

  namespace :crontab do
    desc <<-DESC
      Install cron jobs from current release.
    DESC
    task :update, :roles => crontab_roles do end

    desc <<-DESC
      Clear jobs from crontab.
    DESC
    task :clear, :roles => crontab_roles do end
  end

  require File.expand_path("crontab/#{crontab_provider.to_s}", File.dirname(__FILE__))
end

