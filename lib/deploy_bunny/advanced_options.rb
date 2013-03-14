module DeployBunny
  module AdvancedOptions
    require File.expand_path('advanced_options/options', File.dirname(__FILE__))
    require File.expand_path('advanced_options/servers', File.dirname(__FILE__))
  end
end

Capistrano::Configuration.instance(:must_exist).load do
  _cset(:options_yaml_path) { nil }
  _cset(:servers_yaml_path) { nil }

  _cset(:environment_file_name) { "app-env" }
  _cset(:environment_file_path) { "#{current_release}/#{environment_file_name}" }
  _cset(:in_valid_env)          { ". #{environment_file} && " }

  _cset(:advanced_servers) { DeployBunny::AdvancedOptions::Servers.new(servers_yaml_path) }
  _cset(:advanced_options) { DeployBunny::AdvancedOptions::Options.new(advanced_servers, options_yaml_path) }

  _cset(:deploy_information_to_export) { [:release_name] }

  set(:all_roles) { advanced_servers.unique_roles }

  all_roles.each do |role_name|
    advanced_servers.with_role(role_name).each do |server_address|
      role role_name, server_address
    end
  end

  before 'configuration:export_environment', 'configuration:export_deploy_information'

  namespace :configuration do
    desc <<-DESC
      Export environment variables to file.
      Loads configuration from configuration files \
        located in :options_yaml_path and :servers_yaml_path \
        and stores them in environment variables format to \
        :environment_file_path.

      You can also specify some deploy information to export \
        in :deploy_information_to_export

      Default values:
        set :options_yaml_path, nil # you should specify it in your deploy.rb
        set :servers_yaml_path, nil # you should specify it in your deploy.rb
        set :environment_file_path, ":current_release/:environment_file_name"
        set :environment_file_name, "app-env"
        set :deploy_information_to_export, [:release_name]
    DESC
    task :export_environment do
      find_servers(:roles => all_roles).each do |server|
        put(advanced_options.print_env(server), environment_file_path, hosts: server)
      end
    end

    task :export_deploy_information do
      deploy_information_to_export.each do |k|
        advanced_options[k]= fetch(k)
      end
    end
  end
end

