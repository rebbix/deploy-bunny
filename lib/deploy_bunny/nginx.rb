Capistrano::Configuration.instance(:must_exist).load do
  _cset(:nginx_release_dir)            { current_release }
  _cset(:nginx_dest_config_file_path)  { "/etc/nginx/sites-enabled/#{application}.conf" }
  _cset(:nginx_local_config_file_path) { 'config/nginx.conf' }
  _cset(:nginx_roles)                  { [:web] }

  if respond_to? :log_formatter
    log_formatter([
      { :match => /^nginx:/,           :color => :cyan, :priority => 10 },
      { :match => /^nginx: restoring/, :color => :red,  :priority => 15 }
    ])
  end

  namespace :nginx do
    desc <<-DESC
      Copy :nginx_local_config_file_path to :nginx_config_file_path and reload nginx.
      Uses transaction to return back old configuration file if copy/reload failed.
      Options:
        set :nginx_config_file_path, "/etc/nginx/sites-enabled/:application.conf"
          # global path to nginx configuration file for specific :application

        set :nginx_local_config_file_path, ":current_release/config/nginx.conf"
          # local path to nginx configuration of deployed application
          # usually this is generated with some rake task as part of deploy

        set :nginx_roles, [:web]
          # servers with nginx
    DESC
    task :apply_config, :roles => nginx_roles do
      new_config_file_path = "#{nginx_release_dir}/#{nginx_local_config_file_path}".shellescape
      backup_config_file_path = "#{shared_path}/nginx.#{application}.conf.bak".shellescape
      dest_config_file_path = nginx_dest_config_file_path.shellescape

      transaction do
        on_rollback do
          logger.info 'nginx: restoring old configuration file'
          run [ "[ -f #{backup_config_file_path} ]",
                "&& #{sudo} cp -- #{backup_config_file_path} #{dest_config_file_path}",
                "&& rm -- #{backup_config_file_path}; true"].join(' ')
        end

        logger.info 'nginx: backupping old config file'
        run [ "[ -f #{dest_config_file_path} ]",
              "&& #{sudo} cp -- #{dest_config_file_path} #{backup_config_file_path}; true"].join(' ')

        logger.info 'nginx: copying config file to needed location'
        sudo "cp -- #{new_config_file_path} #{dest_config_file_path}"
        reload
        run "[ -f #{backup_config_file_path} ] && rm -- #{backup_config_file_path}"
      end
    end

    task :rollback, :roles => nginx_roles do
      set :nginx_release_dir, previous_release
      apply_config
    end

    [:start, :stop, :restart, :reload].each do |t|
      t = t.to_s
      desc <<-DESC
        #{t.capitalize} nginx service
      DESC
      eval "task :#{t}, :roles => nginx_roles do
        logger.info 'nginx: performing #{t}'
        sudo 'service nginx #{t}'
      end"
    end

    desc <<-DESC
      Get information about nginx service status
    DESC
    task :status, :roles => nginx_roles do
      sudo "service nginx status"
    end
  end
end
