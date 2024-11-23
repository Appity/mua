lib = File.expand_path('lib', __dir__)

$LOAD_PATH.unshift(lib) unless ($LOAD_PATH.include?(lib))

require 'mua/version'

Gem::Specification.new do |spec|
  spec.name = 'mua'
  spec.version = Mua.version
  spec.authors = [ 'Scott Tadman' ]
  spec.email = [ 'tadman@appity.studio' ]

  spec.summary = %q{Ruby Async Mail User Agent}
  spec.description = %q{Fiberized Mail User Agent Library for Ruby Async}
  spec.homepage = 'https://github.com/appity/mua'
  spec.license = 'MIT'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org/'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/appity/mua'
  spec.metadata['changelog_uri'] = 'https://github.com/appity/mua/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(test|spec|features)/}) }
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w[ lib ]

  spec.add_dependency 'async'
  spec.add_dependency 'async-io'
end
