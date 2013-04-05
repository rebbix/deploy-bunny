require 'net/http'

Capistrano::Configuration.instance(:must_exist).load do

  _cset(:airbrake_host) { '' }
  _cset(:airbrake_api_key) { '' }

  namespace :deploy do
    namespace :send_notifications do
      desc <<-DESC
        Send notifications about deployment to airbrake.
        Setup
          :airbrake_host
          :airbrake_api_key
      DESC
      task :airbrake, :on_error => :continue do
        unless airbrake_api_key.nil? || airbrake_api_key.empty?
          api_key =        URI.encode_www_form_component(airbrake_api_key)
          rails_env =      URI.encode_www_form_component(fetch(:environment, 'production'))
          local_username = URI.encode_www_form_component(user)
          scm_repository = URI.encode_www_form_component(repository)
          scm_revision =   URI.encode_www_form_component(revision)
          if previous_revision
            message =      URI.encode_www_form_component(previous_revision.strip)
          end

          uri = URI "http://#{airbrake_host}/deploys.txt?" +
                        "api_key=#{api_key}&" +
                        "deploy[rails_env]=#{rails_env}&" +
                        "deploy[local_username]=#{local_username}&" +
                        "deploy[scm_repository]=#{scm_repository}&" +
                        "deploy[scm_revision]=#{scm_revision}&" +
                        "deploy[message]=#{message}"

          Net::HTTP.get_response(uri)
        end
      end
    end
  end
end
