Capistrano::Configuration.instance(:must_exist).load do
  _cset(:logs_directory_path) { "#{shared_path}/log" }

  if respond_to? :log_formatter
    log_formatter([
      { :match => /^logging:/,               :color => :cyan,    :priority => 10 },
      { :match => /^logging: Log file is e/, :color => :red,     :priority => 15 },
      { :match => /^logging: Changing path/, :color => :magenta, :priority => 15 }
    ])
  end

  desc "Tasks for monitoring log files."
  namespace :logs do
    desc <<-DESC
      `tail` all *.log files under your :logs_directory_path.

      Default options:
        :logs_directory_path = ":shared_path/log"

      You can define different tasks in this namespace using `define_logfiles`. Example:

        define_logfiles app: 'passanger-nginx-error.log'
          # this command defines new task logs:app which is converted to
          # cd :logs_directory_path && tail -F passenger-nginx-error.log
    DESC
    task :default do
      stream "cd #{logs_directory_path} && tail -F ./*.log"
    end
  end

  def define_logfiles(mapping, task_options={})
    namespace :logs do
      mapping.each do |name, path|
        desc <<-DESC
          Show logs from file: #{path} #{task_options.empty? ? '': "With options: #{task_options}"}.
        DESC
        task name, task_options do
          if capture("cd #{logs_directory_path} && [ -s #{path} ] && echo 1; echo -n ''").empty?
            logger.info "logging: Log file is empty. Maybe application did not reopen log file after rotation"
            path = capture("cd #{logs_directory_path} && ls -1 -rt #{path}* | grep -v '.gz' | tail -n 1").strip
            logger.info "logging: Changing path to '#{path}'"
          end

          if path.empty?
            abort 'Nothing to tail. No such file...'
          end

          begin
            stream "cd #{logs_directory_path} && tail -F ./#{path}"
          rescue Interrupt, SystemExit, SignalException
            abort 'Exiting after user interrupt...'
          end
        end
      end
    end
  end
end
