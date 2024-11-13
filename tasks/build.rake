require 'open3'

# Tested on a system with 32 threads and 32GB of RAM. Adjust threads accordingly.
namespace :overlookinfra do
  desc "Build a given project at a given tag. This should be a tag created via the overlookinfra:tag task."
  task :build, [:project, :tag, :threads] do |t, args|
    args.with_defaults(threads: 8)
    threads = Integer(args[:threads])

    args.with_defaults(project: 'puppet-agent')
    project = args[:project]

    vanagon = 'VANAGON_LOCATION="https://github.com/overlookinfra/vanagon#main"'
    if args[:tag].nil? || args[:tag].empty?
      abort "You must provide a tag."
      return
    end

    cmd = "#{vanagon} #{__dir__}/../build-vanagon.rb #{project} puppet-agent #{args[:tag]} #{threads}"
    puts "Running #{cmd}"
    Open3.popen2e(cmd) do |stdin, stdout_stderr, thread|
      stdout_stderr.each { |line| puts line }
      exit_status = thread.value
      puts "Command finished with status #{exit_status.exitstatus}"
    end
  end
end
