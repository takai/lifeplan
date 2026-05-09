# frozen_string_literal: true

require_relative 'lib/lifeplan/version'

Gem::Specification.new do |spec|
  spec.name = 'lifeplan'
  spec.version = Lifeplan::VERSION
  spec.authors = ['Naoto Takai']
  spec.email = ['takai.naoto@gmail.com']

  spec.summary = 'CLI for managing life planning data with humans and LLM agents.'
  spec.description = 'Lifeplan CLI helps humans and LLM agents create, maintain, ' \
    'validate, and explain life planning data.'
  spec.homepage = 'https://github.com/takai/lifeplan'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0.0'

  spec.files = Dir['lib/**/*.rb', 'bin/*', 'README.md', 'LICENSE', 'docs/**/*.md']
  spec.bindir = 'bin'
  spec.executables = ['lifeplan']
  spec.require_paths = ['lib']

  spec.add_dependency 'thor', '~> 1.3'
end
