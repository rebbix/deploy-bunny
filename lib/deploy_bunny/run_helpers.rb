Capistrano::Configuration.instance(:must_exist).load do
  def bundle_exec(*parameters, &block)
    options = parameters.last.is_a?(Hash) ? parameters.pop.dup : {}
    command = parameters.first

    bundle_cmd = fetch(:bundle_cmd, 'bundle')
    cd_current_release = "cd #{options[:cd] || fetch(:current_release, './')} &&"
    bundle_exec_command = "#{cd_current_release} #{bundle_cmd} exec"

    if command
      run("#{bundle_exec_command} #{command}", options, &block)
    else
      return bundle_exec_command
    end
  end

  def app_env(*parameters, &block)
    options = parameters.last.is_a?(Hash) ? parameters.pop.dup : {}
    command = parameters.first

    app_env_file_path = fetch(:environment_file_path, '')
    app_env_command = app_env_file_path.empty? ? '' : ". #{app_env_file_path} &&"

    if command
      run("#{app_env_command} #{command}", options, &block)
    else
      return app_env_command
    end
  end
end

