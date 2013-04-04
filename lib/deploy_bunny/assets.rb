Capistrano::Configuration.instance(:must_exist).load do

  _cset(:assets_manifests_location) {[
      'public/assets/manifest.yml',
      'public/assets/sources_manifest.yml',
      'assets_manifest.yml']}
  _cset(:share_manifests_over) { [:app] }
  _cset(:manifests_tar_file)   { "manifests-#{release_name}.tar" }

  namespace :deploy do
    namespace :assets do
      desc <<-DESC
        Share manifests over all :share_manifests_over servers.
        By default :share_manifests_over => [:app]
      DESC
      task :share_manifests do
        p find_servers(:roles => share_manifests_over)
        upload_to = find_servers(:roles => share_manifests_over) - find_servers(:roles => assets_role)
        p upload_to

        upload_from = find_servers(:roles => assets_role).first
        unless upload_to.empty?
          compress_known_manifests = <<-END
            tar cf #{manifests_tar_file} --files-from /dev/null;
            cd #{current_release};
            #{assets_manifests_location.map{|f| "[ -f #{f} ] && tar uvf #{manifests_tar_file} #{f}"}.join('; ')};
            cat #{manifests_tar_file} | gzip > #{manifests_tar_file}.gz;
            rm #{manifests_tar_file};
          END

          run compress_known_manifests.compact, :hosts => upload_from
          top.download("#{current_release}/#{manifests_tar_file}.gz", "#{manifests_tar_file}.gz", :hosts => upload_from)
          top.upload("#{manifests_tar_file}.gz", "#{current_release}/#{manifests_tar_file}.gz", :hosts => upload_to)
          run_locally "rm #{manifests_tar_file}.gz"

          run "cd #{current_release} && tar xzf #{manifests_tar_file}.gz", :hosts => upload_to
        end
      end
    end
  end
end