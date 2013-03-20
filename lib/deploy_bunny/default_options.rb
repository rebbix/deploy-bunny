Capistrano::Configuration.instance(:must_exist).load do
  # basic options
  set(:user)     { "deploy" }
  set(:runner)   { user }
  set(:use_sudo) { false }

  set(:branch)    { run_locally("git rev-parse --symbolic-full-name --abbrev-ref HEAD").strip }
  set(:deploy_to) { "/var/www/#{application}" }

  set :revision,  real_revision # not lazy! Causes deadlock (recursion)

  set(:deploy_via)    { :remote_cache }
  set(:keep_releases) { 25 }
  set(:ssh_options)   { {:forward_agent => true} }

  # custom options
  set(:environment) { (exists?(:advanced_options) && advanced_options[:environment]) || 'production' }

  # advanced options
  set(:servers_yaml_path) { 'config/servers.yml' }
  set(:options_yaml_path) { 'config/options.yml' }

  # crontab
  set(:crontab_provider) { :whenever }
end
