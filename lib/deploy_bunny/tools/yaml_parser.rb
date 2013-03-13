require 'yaml'

module DeployBunny
  module Tools
    module YamlParser
      def parse_yaml_file(file_path, default={})
        contents = default
        contents = YAML::load_file(file_path) unless file_path.nil?
        contents
      rescue
        contents
      end
    end
  end
end
