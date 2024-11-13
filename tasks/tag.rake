require 'open3'
namespace :overlookinfra do
  desc "Apply overlookinfra changes to given tag, and create new tag. First argument is the puppetlabs tag, second is the overlook tag for puppet-runtime, third is the overlook tag for pxp-agent."
  task :tag, [:tag, :puppet_runtime_tag, :pxp_agent_tag] do |t, args|
    patch_branch = 'plumbing'
    patch_file = 'overlookinfra.patch'
    if args[:tag].nil? || args[:tag].empty?
      abort "You must provide a tag."
    end
    if args[:puppet_runtime_tag].nil? || args[:puppet_runtime_tag].empty?
      abort "You must provide a tag for puppet-runtime that has been uploaded to s3.osuosl.org."
    end
    if args[:pxp_agent_tag].nil? || args[:pxp_agent_tag].empty?
      abort "You must provide a tag for puppet-runtime that has been uploaded to s3.osuosl.org."
    end
    branch = "overlookinfra/#{args[:tag]}"
    tag = "#{args[:tag]}-overlookinfra"
    
    puts "Checking out #{args[:tag]}"
    run_command("git checkout #{args[:tag]}")

    puts "Checking out #{patch_file}"
    run_command("git checkout #{patch_branch} -- #{patch_file}")

    puts "Applying patch"
    run_command("git apply #{patch_file}")

    puts "Replacing puppet-runtime.json"
    munged = args[:puppet_runtime_tag].gsub('-','.')
    data = <<~DATA
      {"location":"https://s3.osuosl.org/puppet-artifacts/puppet-runtime/#{args[:puppet_runtime_tag]}/","version":"#{munged}"}
    DATA
    File.write("configs/components/puppet-runtime.json",data)

    puts "Replacing pxp-agent.json"
    munged = args[:pxp_agent_tag].gsub('-','.')
    data = <<~DATA
      {"location":"https://s3.osuosl.org/puppet-artifacts/pxp-agent/#{args[:pxp_agent_tag]}/","version":"#{munged}"}
    DATA
    File.write("configs/components/pxp-agent.json",data)

    puts "Creating commit"
    run_command("git add .")
    run_command("git rm -f #{patch_file}")
    run_command("git commit -m \"#{tag}\"")

    puts "Creating tag #{tag}"
    sha = run_command("git rev-parse HEAD")
    run_command("git tag -a #{tag} -m #{tag} #{sha}")

    puts "Creating branch #{branch}"
    run_command("git checkout -b #{branch}")

    puts "Pushing to origin"
    run_command("git push origin #{branch}")
    run_command("git push origin #{tag}")
  end
end

def run_command(cmd)
  output, status = Open3.capture2e(cmd)
  abort "Command failed! Command: #{cmd}, Output: #{output}" unless status.exitstatus.zero?
  return output.chomp
end