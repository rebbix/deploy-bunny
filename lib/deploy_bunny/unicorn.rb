Capistrano::Configuration.instance(:must_exist).load do
  _cset(:unicorn_run_from_dir)     { current_release }
  _cset(:unicorn_pid_file_path)    { "#{unicorn_run_from_dir}/tmp/pids/unicorn.pid" }
  _cset(:unicorn_config_file_path) { "#{unicorn_run_from_dir}/config/unicorn.rb" }

  _cset(:unicorn_roles)  { [:app] }
  _cset(:unicorn_bin)    { 'unicorn' }
  _cset(:unicorn_pid)    { "`cat #{unicorn_pid_file_path}`" }

  def unicorn_is_running?
    "[ -e #{unicorn_pid_file_path} ] && kill -0 #{unicorn_pid} > /dev/null 2>&1"
  end

  def with_running_unicorn(break_on_else=false)
    command = yield

    <<-END
      set -x;
      if #{unicorn_is_running?}; then
        #{command}
      else
        echo "unicorn: status - not running";
        #{'exit 1;' if break_on_else}
      fi;
    END
  end

  def kill_unicorn(signal)
    with_running_unicorn do
      "kill -s #{signal} #{unicorn_pid};"
    end
  end

  if respond_to? :log_formatter
    log_formatter([
      { :match => /^unicorn:/,        :color => :cyan,    :priority => 10 },
      { :match => /^unicorn: status/, :color => :magenta, :priority => 15 }
    ])
  end

  namespace :unicorn do
    desc <<-DESC
    DESC
    task :start, :roles => unicorn_roles do
      app_env "#{bundle_exec} #{unicorn_bin} -c #{unicorn_config_file_path} -E #{fetch(:environment, 'production')} -D"
    end

    desc <<-DESC
    DESC
    task :stop, :roles => unicorn_roles do
      run kill_unicorn('QUIT')
    end

    desc <<-DESC
    DESC
    task :terminate, :roles => unicorn_roles do
      run kill_unicorn('TERM')
    end

    desc <<-DESC
    DESC
    task :soft_restart, :roles => unicorn_roles do
      transaction do
        on_rollback do
          start
        end

        run(with_running_unicorn(true) do
          "kill -s USR2 #{unicorn_pid};"
        end)
      end
    end

    desc <<-DESC
    DESC
    task :hard_restart, :roles => unicorn_roles do
      stop
      sleep 2
      start
    end

    desc <<-DESC
    DESC
    task :add_worker, :roles => unicorn_roles do
      run kill_unicorn('TTIN')
    end

    desc <<-DESC
    DESC
    task :remove_worker, :roles => unicorn_roles do
      run kill_unicorn('TTOU')
    end

    desc <<-DESC
    DESC
    task :status, :roles => unicorn_roles do
      run(with_running_unicorn do
        'echo "unicorn: status - running";'
      end)
    end
  end
end
