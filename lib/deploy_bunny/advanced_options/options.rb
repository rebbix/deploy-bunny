require File.expand_path('../tools', File.dirname(__FILE__))

module DeployBunny
  module AdvancedOptions
    class Options
      include Tools::YamlParser

      def initialize(servers=nil, config_path=nil)
        @advanced_servers = servers
        @raw_configuration = parse_yaml_file(config_path, 'env' => {})
        @cached_configuration = {}
        @set_options = {}
        @servers = Hash[@advanced_servers.unique_roles.map {|role| ["#{role}_servers", server_names_with_role(role)]}]
      end

      def generic_options
        @generic_options ||= {}
          .merge(Hash[@servers.map { |k, s| [k, s.join(' ')]}])
          .merge(@set_options)
      end

      def set(key, value=nil)
        unless key.is_a?(Hash)
          key = Hash[key, value]
        end

        key.each { |k, v| save_option!(k, v) }
      end

      alias []= set

      def get(option, server=nil)
        options_for(server)[option.to_s.downcase]
      end

      def [](option)
        get(option)
      end

      def print_env(server=nil)
        options_for(server)
          .merge(generic_options)
          .map {|key, value| %(export #{key.upcase}="#{value}")}.join("\n")
      end

      protected

        def server_names_with_role(role)
          return ['127.0.0.1'] if @advanced_servers.nil?

          @advanced_servers.with_role(role).map { |sn| "#{sn.sub(/:\d{2,4}\z/, '')}" }
        end

        def save_option!(key, value)
          @set_options[key.to_s] = value
          @generic_options = nil
        end

        def options_for(server=nil)
          @cached_configuration[server] ||= @raw_configuration['env']
            .merge(server_specific_options_for server)
        end

        def server_specific_options_for(server=nil)
          return {} if @servers.nil? || server.nil?
          @advanced_servers.server_specific_options_for(server, {})
        end
    end
  end
end
