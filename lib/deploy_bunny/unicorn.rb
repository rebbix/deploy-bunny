Capistrano::Configuration.instance(:must_exist).load do
  _cset(:unicorn_run_from_dir)     { current_path }
  _cset(:unicorn_pid_file_path)    { "#{unicorn_run_from_dir}/tmp/pids/unicorn.pid" }
  _cset(:unicorn_config_file_path) { "#{unicorn_run_from_dir}/config/unicorn.rb" }

  _cset(:unicorn_roles)  { [:app] }
  _cset(:unicorn_bin)    { 'unicorn' }
  _cset(:unicorn_pid)    { "`cat #{unicorn_pid_file_path}`" }

  def unicorn_is_running?
    "[ -e #{unicorn_pid_file_path} ] && kill -0 #{unicorn_pid} > /dev/null 2>&1"
  end

  def if_unicorn_is_running(cases={})
    cases = {
      yes: "echo 'unicorn: status - running'; ps x -o pid,ppid,command | grep #{unicorn_pid} | grep -v grep;",
      no: 'echo "unicorn: status - not running";'
    }.merge(cases)

    <<-END
      if #{unicorn_is_running?}; then
        #{cases[:yes]}
      else
        #{cases[:no]}
      fi;
    END
  end

  def unicorn_start_command
    <<-END
      echo 'unicorn: starting';
      #{app_env} #{bundle_exec cd: unicorn_run_from_dir} #{unicorn_bin} -c #{unicorn_config_file_path} -E #{fetch(:environment, 'production')} -D;
    END
  end

  def wait_for_quit_or_timeout(pid, cases={}, timeout=120)
    cases = {
      quit: '',
      timeout: 'echo "unicorn: old master process is not quiting" 1>&2 ;'
    }.merge(cases)

    <<-END
      number_of_loops=#{timeout};
      while [ "$number_of_loops" -gt "0" ]; do
        sleep 1;
        echo "unicorn: waiting for old master to quit...";
        number_of_loops=$(( $number_of_loops - 1 ));
        if [ ! -f "#{pid}" ]; then #{cases[:quit]} exit 0; fi;
      done;

      #{cases[:timeout]}
      exit 1;
    END
  end

  def kill_unicorn(signal)
    if_unicorn_is_running(yes: "kill -s #{signal} #{unicorn_pid};")
  end

  if respond_to? :log_formatter
    log_formatter([
      { :match => /^unicorn:/,        :color => :cyan,    :priority => 10 },
      { :match => /^unicorn: status/, :color => :magenta, :priority => 15 }
    ])
  end

  namespace :unicorn do
    desc <<-DESC
      Start unicorn web server.
      Start in demonized mode from :unicorn_run_from_dir with config from :unicorn_config_file_path. \
      It is running in :environment mode and pid is located under :unicorn_pid_file_path

      Default values:

        :unicorn_run_from_dir      :current_release
        :unicorn_pid_file_path     ":unicorn_run_from_dir/tmp/pids/unicorn.pid"
        :unicorn_config_file_path  ":unicorn_run_from_dir/config/unicorn.rb"

        :unicorn_roles  [:app]
        :unicorn_bin    'unicorn'
    DESC
    task :start, :roles => unicorn_roles do
      run unicorn_start_command
    end

    desc <<-DESC
      Gracefully stop unicorn web server.
    DESC
    task :stop, :roles => unicorn_roles do
      run kill_unicorn('QUIT')
    end

    desc <<-DESC
      Forcefully stop web server with SIG TERM.
    DESC
    task :terminate, :roles => unicorn_roles do
      run kill_unicorn('TERM')
    end

    desc <<-DESC
      Restart unicorn with zero downtime.
      You should also take care about killing old master process.
    DESC
    task :soft_restart, :roles => unicorn_roles do
      unicorn_restart_command = <<-END
        kill -s USR2 #{unicorn_pid};
        #{wait_for_quit_or_timeout("#{unicorn_pid_file_path}.oldbin")}
      END

      run if_unicorn_is_running({
        yes: unicorn_restart_command,
        no: unicorn_start_command
      })
    end

    desc <<-DESC
      Restart unicorn by stopping old master process and starting new one.
    DESC
    task :hard_restart, :roles => unicorn_roles do
      unicorn_restart_command = <<-END
        kill -s QUIT #{unicorn_pid};
        #{wait_for_quit_or_timeout(unicorn_pid_file_path, {
          quit: unicorn_start_command
        })}
      END

      run if_unicorn_is_running({
        yes: unicorn_restart_command,
        no: unicorn_start_command
      })
    end

    desc <<-DESC
      Increment unicorn workers count.
    DESC
    task :add_worker, :roles => unicorn_roles do
      run kill_unicorn('TTIN')
    end

    desc <<-DESC
      Decrement unicorn workers count.
    DESC
    task :remove_worker, :roles => unicorn_roles do
      run kill_unicorn('TTOU')
    end

    desc <<-DESC
      Get information if unicorn is running.
    DESC
    task :status, :roles => unicorn_roles do
      run if_unicorn_is_running
    end
  end
end
