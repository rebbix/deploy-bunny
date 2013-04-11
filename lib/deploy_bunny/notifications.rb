Capistrano::Configuration.instance(:must_exist).load do

  _cset(:notification_providers) do
    {
      email:    -> { !fetch(:emails_to_notify, '').empty? },
      newrelic: -> { !fetch(:newrelic_license_key, nil).nil? && !fetch(:newrelic_license_key, '').empty? },
      airbrake: -> { !fetch(:airbrake_api_key, nil).nil? && !fetch(:airbrake_api_key, '').empty? }
    }.select{ |_, condition| condition.call }.keys
  end

  if notification_providers.count > 0
    notification_providers.each do |provider|
      require File.expand_path("notifications/#{provider.to_s}", File.dirname(__FILE__))
    end

    after 'deploy:update', 'deploy:send_notifications'

    namespace :deploy do
      namespace :send_notifications do

        desc <<-DESC
        Send notifications about deploy.
        Currently supported notifications:
          #{notification_providers.join("\n")}
        DESC

        task :default do
          notification_providers.each { |notification| send(notification) }
        end
      end
    end
  end
end
