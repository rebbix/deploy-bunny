require 'net/http'

# TODO: needs refactoring
# Split to different files (per provider)
# Make possible to turn on/off notifications

Capistrano::Configuration.instance(:must_exist).load do

  _cset(:emails_to_notify) { [] }

  _cset(:newrelic_license_key) { '' }
  _cset(:newrelic_app_name) { '' }

  _cset(:airbrake_host) { '' }
  _cset(:airbrake_api_key) { '' }

  after 'deploy:update', 'deploy:send_notifications'

  namespace :deploy do
    namespace :send_notifications do
      desc <<-DESC
        Send notifications about deploy.
        Currently supported notifications:
          * email
          * newrelic
          * airbrake
      DESC
      task :default do
        notify_emails
        notify_newrelic
        notify_airbrake
      end

      task :notify_emails do
        unless emails_to_notify.empty?
          notification_message = <<-MESSAGE
            This email was generated by Capistrano before delivery.

            -------------------------------------------------------
            Current deploy Branch: #{branch.strip}
            Current deploy Revision: #{revision.strip}

            Previous deploy Revision: #{previous_revision.strip}
            -------------------------------------------------------

            See this commit on Github: #{repository.sub(':', '/').sub('git@', 'https://').sub('.git', "/commit/#{revision.strip}")}
            See changelist on Github: #{repository.sub(':', '/').sub('git@', 'https://').sub('.git', "/compare/#{previous_revision}...#{revision.strip}")}
          MESSAGE
          run_locally %(echo "#{notification_message}" | mail -s "Aquatika delivery by #{user}" '#{emails_to_notify.join("' '")}')
        end
      end

      task :notify_newrelic, :on_error => :continue do
        unless newrelic_license_key.nil? || newrelic_license_key.empty?
          newrelic_config = <<-TEMPLATE
            common: &default_settings
              license_key: '#{newrelic_license_key}'
              app_name: '#{newrelic_app_name}'
              monitor_mode: true
              developer_mode: false
              log_level: info
              ssl: false
              apdex_t: 0.5
              browser_monitoring:
                auto_instrument: true
              capture_params: true
              transaction_tracer:
                enabled: true
                transaction_threshold: apdex_f
                record_sql: obfuscated
                stack_trace_threshold: 0.500
              error_collector:
                enabled: true
                capture_source: true
                ignore_errors: ActionController::RoutingError
            development:
              <<: *default_settings
              monitor_mode: false
              developer_mode: true
            test:
              <<: *default_settings
              monitor_mode: false
            production:
              <<: *default_settings
              monitor_mode: true
            staging:
              <<: *default_settings
              monitor_mode: true
          TEMPLATE

          run_locally "[ -f config/newrelic.yml ] && mv config/newrelic.yml config/newrelic.yml.bak; echo '--> bak'"

          File.open('config/newrelic.yml', "w+") do |f|
            f.write(newrelic_config)
          end

          newrelic.notice_deployment

          run_locally "[ -f config/newrelic.yml.bak ] && mv config/newrelic.yml.bak config/newrelic.yml; echo 'bak -->'"
        end
      end

      task :notify_airbrake, :on_error => :continue do
        unless airbrake_api_key.nil? || airbrake_api_key.empty?
          api_key =        URI.encode_www_form_component(airbrake_api_key)
          rails_env =      URI.encode_www_form_component(fetch(:environment, 'production'))
          local_username = URI.encode_www_form_component(user)
          scm_repository = URI.encode_www_form_component(repository)
          scm_revision =   URI.encode_www_form_component(revision)
          if previous_revision
            message =      URI.encode_www_form_component(previous_revision.strip)
          end

          uri = URI %(http://#{airbrake_host}/deploys.txt?api_key=#{api_key}&deploy[rails_env]=#{rails_env}&deploy[local_username]=#{local_username}&deploy[scm_repository]=#{scm_repository}&deploy[scm_revision]=#{scm_revision}&deploy[message]=#{message})

          Net::HTTP.get_response(uri)
        end
      end
    end
  end

end
