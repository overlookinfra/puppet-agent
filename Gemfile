source ENV['GEM_SOURCE'] || "https://rubygems.org"

def location_for(place)
  if place =~ /^((?:git[:@]|https:)[^#]*)#(.*)/
    [{ :git => $1, :branch => $2, :require => false }]
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

# We must do this here in the plumbing branch so that when the build script
# runs with VANAGON_LOCATION set, it already has the right gem installed.
# Bundler seems to get confused when the rake tasks runs with a different
# vanagon version in the bundle.
gem 'vanagon', *location_for("https://github.com/overlookinfra/vanagon#main")
gem 'packaging', *location_for(ENV['PACKAGING_LOCATION'] || '~> 0.105')
gem 'artifactory'
gem 'rake'
gem 'json'
gem 'octokit'
gem 'rubocop', "~> 1.22"

eval_gemfile("#{__FILE__}.local") if File.exist?("#{__FILE__}.local")
