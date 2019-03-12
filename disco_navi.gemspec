# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name = 'disco-navi'
  spec.version = '0.0.1'
  spec.author = 'Nathan Armstrong'
  spec.email = 'nathan@functionalflame.tech'

  spec.summary = 'A Discord bot, currently designed for tinkering at the moment.'
  spec.license = 'Apache-2.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  unless spec.respond_to?(:metadata)
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(/^(test|spec|features)/)
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 2.5'

  spec.add_dependency 'discordrb', '~> 3.2.1'
  spec.add_dependency 'dotenv', '~> 2.7.1'
  spec.add_dependency 'hashie', '~> 3.6.0'
  spec.add_dependency 'httparty', '~> 0.16.4'
  spec.add_dependency 'parslet', '~> 1.8.2'

  spec.add_development_dependency 'bundler', '~> 1.16.3'
  spec.add_development_dependency 'rake', '~> 12.3.2'
  spec.add_development_dependency 'rspec', '~> 3.8.0'
  spec.add_development_dependency 'rubocop', '~> 0.65.0'
end
