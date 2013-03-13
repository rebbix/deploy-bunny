require File.expand_path('../tools', File.dirname(__FILE__))

module DeployBunny
  module AdvancedOptions
    class Servers
      include Tools::YamlParser

      def initialize(config_path=nil)
        @raw_configuration = parse_yaml_file(config_path)
        @cached_configuration = {}
      end

      def unique_roles
        @unique_roles ||= @raw_configuration.fetch('servers', {}).keys
      end

      def with_role(role)
        @cached_configuration[role] ||= get_servers_by_role(role.to_s)
      end

      def server_specific_options_for(server, default={})
        @raw_configuration['options'].fetch(server, @raw_configuration['options'].fetch('default', default))
      end

      protected

        def get_servers_by_role(role)
          servers = [@raw_configuration['servers'][role]].flatten

          servers.map do |hostname|
            if @raw_configuration['bindings'].has_key? hostname
              hostname = @raw_configuration['bindings'][hostname]
            end

            hostname
          end.flatten.uniq
        end
    end
  end
end
