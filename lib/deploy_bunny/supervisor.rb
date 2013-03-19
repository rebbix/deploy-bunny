Capistrano::Configuration.instance(:must_exist).load do
  _cset(:supervisord_run_from_dir)      { current_release }
  _cset(:supervisord_pid_file_path)     { "#{supervisord_run_from_dir}/tmp/pids/supervisord.pid" }
  _cset(:supervisord_logs_file_path)    { "#{supervisord_run_from_dir}/log/supervisord.log" }
  _cset(:supervisord_config_file_path)  { "#{supervisord_run_from_dir}/config/supervisord.conf" }
  _cset(:supervisord_stop_wait_timeout) { 10 }

  _cset(:supervisord_app_id) { application }
  _cset(:supervisord_roles)  { [:app] }
  _cset(:supervisord_pid)    { ['ps axo "%p:%a"',
                                'grep "supervisord"',
                                %(grep "#{supervisord_app_id}"),
                                'grep -v grep',
                                'sed "s/:.*//"',
                                'sed "s/\s*//"',
                                'head -1'].join(' | ') }

  if respond_to? :log_formatter
    log_formatter([
      { :match => /^supervisord:/,        :color => :cyan,    :priority => 10 },
      { :match => /^supervisord: status/, :color => :magenta,  :priority => 15 }
    ])
  end

  namespace :supervisor do
    desc <<-DESC
      Start workers under supervisord.
      Workers are defined in :supervisord_config_file_path and started under \
      :supervisord_run_from_dir. Supervisord creates pid file under \
      :supervisord_pid_file_path and log file under :supervisord_logs_file_path.

      Workers are identified by :supervisord_app_id and are strted on servers \
      with roles :supervisord_roles

      Default values:
        :supervisord_app_id           - :application
        :supervisord_roles            - [:app]

        :supervisord_run_from_dir     - :current_release
        :supervisord_pid_file_path    - :supervisord_run_from_dir/tmp/pids/supervisord.pid
        :supervisord_logs_file_path   - :supervisord_run_from_dir/log/supervisord.log
        :supervisord_config_file_path - :supervisord_run_from_dir/config/supervisord.conf
    DESC
    task :start, :roles => supervisord_roles do
      logger.info "supervisord: starting workers"

      run [%(if [ -z `#{supervisord_pid}` ]; then),
             %(cd #{supervisord_run_from_dir};),
             %(#{app_env} supervisord -c "#{supervisord_config_file_path}"),
                                    %(-i "#{supervisord_app_id}"),
                                    %(-l "#{supervisord_logs_file_path}"),
                                    %(-j "#{supervisord_pid_file_path}";),
           %(else),
             %(echo "Some supervisord instance is already running with pid: [`#{supervisord_pid}`]";),
           %(fi)].join(' ')
    end

    desc <<-DESC
      Stop workers running under supervisord.
    DESC
    task :stop, :roles => supervisord_roles do
      logger.info "supervisord: stopping workers"

      run [%(if [ ! -z `#{supervisord_pid}` ]; then),
             %(cd #{supervisord_run_from_dir};),
             %(#{app_env} supervisorctl -c "#{supervisord_config_file_path}" shutdown;),
             %(n=#{supervisord_stop_wait_timeout};),
             %(while [ "$n" -gt "0" ]; do),
               %(sleep 1 && echo "Waiting for shutdown...";),
               %(n=$(( $n - 1 ));),
               %(if [ -z `#{supervisord_pid}` ]; then exit 0; fi;),
             %(done;),
             %(if [ "$n" -le "0" ]; then),
               %(echo "Failed to gracefully stop supervisord";),
               %(exit 1;),
             %(fi;),
           %(fi)].join(' ')

    end

    desc <<-DESC
      Restart supervisord and workers running under it.
    DESC
    task :restart, :roles => supervisord_roles do
      stop
      start
    end

    desc <<-DESC
      Show status of running workers.

      Format:
      <worker_name> <STATUS>  pid <pid>, uptime: <uptime_in_format_h:mm:ss>
    DESC
    task :status, :roles => supervisord_roles do
      results = [].tap do |results|
        run("if [ -z `#{supervisord_pid}` ]; then echo -n 'true'; fi") do |ch, stream, out|
          results << (out == 'true')
        end
      end.uniq

      if results == [true]
        logger.info "supervisord: status - all instances stopped"
      else
        if results == []
          logger.info "supervisord: status - all instances are running"
        else
          logger.info "supervisord: status - some instances are running"
        end

        run [%(if [ ! -z `#{supervisord_pid}` ]; then),
               %(cd #{supervisord_run_from_dir};),
               %(#{app_env} supervisorctl -c "#{supervisord_config_file_path}" status;),
             %(fi)].join(' ')
      end
    end

  end
end