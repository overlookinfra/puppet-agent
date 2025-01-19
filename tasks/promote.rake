require 'open3'

namespace :vox do
  desc 'Promote a puppet-runtime or pxp-agent tag into this repo'
  task :promote, [:component, :tag] do |_, args|
    abort 'Component must be "puppet-runtime" or "pxp-agent"' unless !args[:component].nil? && ['puppet-runtime', 'pxp-agent'].include?(args[:component])
    abort 'You must provide a tag for puppet-runtime that has been uploaded to s3.osuosl.org.' if args[:tag].nil? || args[:tag].empty?

    branch = run_command('git rev-parse --abbrev-ref HEAD')

    munged = args[:tag].gsub('-', '.')
    data = <<~DATA
      {"location":"https://s3.osuosl.org/openvox-artifacts/#{args[:component]}/#{args[:tag]}/","version":"#{munged}"}
    DATA

    puts "Writing #{args[:component]}.json"
    File.write("configs/components/#{args[:component]}.json", data)
    run_command("git add configs/components/#{args[:component]}.json")
    puts 'Creating commit'
    run_command("git commit -m 'Promote #{args[:component]} #{args[:tag]}'")
    puts 'Pushing to origin'
    run_command("git push origin #{branch}")
  end
end
