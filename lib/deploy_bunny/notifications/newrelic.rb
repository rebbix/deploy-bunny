begin

require 'new_relic/recipes'

Capistrano::Configuration.instance(:must_exist).load do

  _cset(:newrelic_license_key) { '' }
  _cset(:newrelic_app_name) { '' }

  namespace :deploy do
    namespace :send_notifications do
      desc <<-DESC
        Send notifications about deploy to newrelic.
        Needs to know:
          :newrelic_license_key
          :newrelic_app_name
      DESC
      task :newrelic, :on_error => :continue do
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

          run_locally '[ -f config/newrelic.yml ] && mv config/newrelic.yml config/newrelic.yml.bak; echo "--> bak"'

          File.open('config/newrelic.yml', 'w+') do |f|
            f.write(newrelic_config)
          end

          top.newrelic.notice_deployment

          run_locally '[ -f config/newrelic.yml.bak ] && mv config/newrelic.yml.bak config/newrelic.yml; echo "bak -->"'
        end
      end
    end
  end
end

rescue
puts 'ERROR: Please install newrelic_rpm to notify newrelic about deployments'
end
