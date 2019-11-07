lib = File.expand_path('lib', __dir__)

$LOAD_PATH.unshift(lib) unless ($LOAD_PATH.include?(lib))

require 'asmail/version'

Gem::Specification.new do |spec|
  spec.name = 'asmail'
  spec.version = ASMail.version
  spec.authors = [ 'Scott Tadman' ]
  spec.email = [ 'tadman@postageapp.com' ]

  spec.summary = %q{Ruby Async Mail Library}
  spec.description = %q{Fiberized Mail Library for Ruby Async}
  spec.homepage = 'https://github.com/postageapp/asmail'
  spec.license = 'MIT'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org/'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/postageapp/asmail'
  spec.metadata['changelog_uri'] = 'https://github.com/postageapp/asmail/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(test|spec|features)/}) }
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w[ lib ]

  spec.add_dependency 'async'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
