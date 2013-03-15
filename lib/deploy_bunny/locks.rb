require 'json'

Capistrano::Configuration.instance(:must_exist).load do
  _cset(:generic_lock_users) { ['vagrant', 'deploy', 'user', fetch(:user, 'user')].uniq }
  _cset(:lock_user_environment_variable) { 'LOCK_USER' }

  _cset(:lock_path)    { "#{shared_path}/system/deploy_lock.txt" }
  _cset(:lock_message) { ENV['MESSAGE'] || ENV['MSG'] || 'Default lock message. Use MSG=msg to customize it' }
  _cset(:lock_user) do
    lock_user = ENV[lock_user_environment_variable] || ENV['USER']
    if generic_lock_users.include?(lock_user)
      logger.info "lock-system: To avoid entering your name everytime, you may run `export #{lock_user_environment_variable}=<username>`"
      lock_user = Capistrano::CLI.ui.ask('Please enter your name: ')
    end
    lock_user
  end

  if respond_to? :log_formatter
    log_formatter([
      { :match => /lock-system/,           :color => :magenta, :priority => 10 },
      { :match => /lock-system: locked b/, :color => :green,   :priority => 15 },
      { :match => /lock-system: locked -/, :color => :red,     :priority => 15 },
      { :match => /lock-system: forcibly/, :color => :red,     :priority => 15 }
    ])
  end

  before 'deploy:setup',    'deploy:check_lock'

  before 'deploy',          'deploy:check_lock'

  before 'deploy:restart',  'deploy:check_lock'
  before 'deploy:stop',     'deploy:check_lock'
  before 'deploy:start',    'deploy:check_lock'

  before 'deploy:rollback', 'deploy:check_lock'

  namespace :deploy do
    desc <<-DESC
      Prevent other people from deploying.
      You can specify message using `MESSAGE` environment variable.
      And you can specify different user using `USER` environment variable.
      Example:
        MESSAGE=lol USER=taras cap deploy:lock
          # This command locks server from deploys with message "lol".
          # The only user who can deploy is "taras".
          # Other users get error message.
    DESC
    task :lock do
      check_lock

      timestamp = Time.now.strftime("%m/%d/%Y %H:%M:%S %Z")
      lock_meta = {
          user: lock_user,
          message: "Locked by #{lock_user} at #{timestamp}: #{lock_message}"
      }
      put(lock_meta.to_json, lock_path, :mode => 0644)
    end

    desc <<-DESC
      Abort if locked by other person. \
      If locked by you, or no lock at all - do nothing.
    DESC
    task :check_lock do
      logger.info "lock-system: Checking lock"
      data_string = capture("cat #{lock_path} 2>/dev/null;echo").to_s.strip

      unless data_string.empty?
        data = JSON.parse(data_string, symbolize_names: true)

        if data[:user] == lock_user
          logger.info "lock-system: Locked by you, skipping..."
        else
          logger.info "lock-system: Locked - #{data[:message]}"

          abort "Failed to deploy. Ask #{data[:user]} to release lock"
        end
      end
    end

    desc <<-DESC
      Remove own deploy lock.
    DESC
    task :unlock do
      check_lock
      run "rm -f #{lock_path}"
    end

    desc <<-DESC
      Remove any deploy lock. \
      Use it with caution when it is not possible to release lock by deploy:unlock.
    DESC
    task :force_unlock do
      logger.info "lock-system: Forcibly removing the lock!!!"
      run "rm -f #{lock_path}"
    end
  end
end
