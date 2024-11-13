#!/usr/bin/env ruby

require 'io/console'
require 'open3'
require 'fileutils'

# USAGE: ./build-vanagon.rb <vanagon project name> <folder name> <version> <number of threads>

PLATFORM_LIST = [
    'amazon-2-aarch64',
    'amazon-2023-aarch64',
    'amazon-2023-x86_64',
    'debian-10-amd64',
    'debian-11-aarch64',
    'debian-11-amd64',
    'debian-12-aarch64',
    'debian-12-amd64',
    'el-7-x86_64',
    'el-8-aarch64',
    'el-8-x86_64',
    'el-8-ppc64le',
    'el-9-aarch64',
    'el-9-x86_64',
    'el-9-ppc64le',
    'fedora-36-x86_64',
    'fedora-40-x86_64',
    'sles-15-x86_64',
    'ubuntu-18.04-aarch64',
    'ubuntu-18.04-amd64',
    'ubuntu-20.04-aarch64',
    'ubuntu-20.04-amd64',
    'ubuntu-22.04-aarch64',
    'ubuntu-22.04-amd64',
    'ubuntu-24.04-aarch64',
    'ubuntu-24.04-amd64',
]

@project = ARGV[0] # Name of project in vanagon
@repo = ARGV[1] # Name of folder/repo
@version = ARGV[2]
# Recommended values for 32 hardware threads and 32GB RAM
#   puppet-runtime: 8
#   pxp-agent: 4
@instance_num = [Integer(ARGV[3]), PLATFORM_LIST.count].min

@thread_messages = {}
@thread_platforms = {}
@failed_platforms = []
@completed_platforms = []
@mutex = Mutex.new
@timestamp = Time.now.strftime('%Y%m%d_%H%M%S')

class ThreadPool
    def initialize(size)
        @size = size
        @queue = Queue.new
        @threads = Array.new(size) do
            Thread.new do
                until (task = @queue.pop) == :stop
                    task.call
                end
            end
        end
    end

    def schedule(&task)
        @queue << task
    end

    def shutdown
        @size.times { @queue << :stop }
        @threads.each(&:join)
    end
end

def safe_print(thread_id, message)
    @thread_messages[thread_id] = @thread_messages[thread_id] || []
    @thread_messages[thread_id] << message

    @mutex.synchronize do
        print "\e[H\e[2J"
        print "Building #{@project}\n\n"
        @thread_messages.keys.sort.each do |i|
            print "Thread #{i} (#{@thread_platforms[i]}): #{@thread_messages[i][-1]}\n\n"
        end
        print "Platforms in the queue: \n#{(PLATFORM_LIST - @thread_platforms.values - @completed_platforms).join("\n")}\n\n"
        print "Failed platforms: \n#{@failed_platforms.join("\n")}"
        $stdout.flush
    end
end

def thread_message_dump(thread_id)
    File.open("#{__dir__}/#{@repo}_#{@thread_platforms[thread_id]}_#{@timestamp}.txt", 'w') do |f|
        f.write(@thread_messages[thread_id].join("\n"))
    end
end

def merge_directories(source, target)
    FileUtils.mkdir_p(target)
    FileUtils.cp_r(Dir["#{source}/."], target)
end

def build(thread_id, platform, repo, project)
    Thread.current.report_on_exception = false
    safe_print(thread_id, "Starting build of #{platform}")
    dir = "/tmp/#{repo}.#{thread_id}.#{@timestamp}"
    FileUtils.cp_r("#{__dir__}/../#{repo}", dir)
    begin
        run(thread_id, dir, "git checkout #{@version}")
        run(thread_id, dir, "rm -rf .bundle")
        run(thread_id, dir, "rm -f Gemfile.lock")
        run(thread_id, dir, "bundle install")
        run(thread_id, dir, "rm -rf output")
        run(thread_id, dir, "bundle exec build #{project} #{platform} --engine docker")
        merge_directories("#{dir}/output", "#{__dir__}/../#{repo}/output")
        safe_print(thread_id, "Done building #{platform}")
    rescue Exception => e
        @mutex.synchronize { @failed_platforms << platform }
        safe_print(thread_id, e)
        thread_message_dump(thread_id)
    ensure
        FileUtils.rm_rf(dir)
    end
end

def run(thread_id, dir, command)
    Open3.popen2e(command, chdir: dir) do |stdin, stdout_stderr, wait_thr|
        stdout_stderr.each_line do |line|
            safe_print(thread_id, line.chomp)
        end
        exit_status = wait_thr.value
        unless exit_status.success?
            raise "Command failed with exit status: #{exit_status.exitstatus}"
        end
    end
end

start = Time.now
pool = ThreadPool.new(@instance_num)

PLATFORM_LIST.each do |plat|
    pool.schedule do
        thread_id = "#{Process.pid}-#{Thread.current.object_id}"
        @mutex.synchronize do
            @thread_messages[thread_id] = []
            @thread_platforms[thread_id] = plat
        end
        build(thread_id, plat, @repo, @project)
        @mutex.synchronize { @completed_platforms << plat }
    end
end

pool.shutdown

unless @failed_platforms.empty?
    puts "Failed platforms:"
    puts @failed_platforms.join("\n")
end
puts "Total time: #{Time.now - start}"