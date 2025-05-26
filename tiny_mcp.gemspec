# frozen_string_literal: true

require_relative 'lib/tiny_mcp/version'

Gem::Specification.new do |spec|
  spec.name = 'tiny_mcp'
  spec.version = TinyMCP::VERSION
  spec.authors = ['Max Chernyak']
  spec.email = ['hello@max.engineer']

  spec.summary = 'Tiny Ruby-based MCP server'
  spec.description = 'Make local MCP tools in Ruby and easily serve them.'
  spec.homepage = 'https://github.com/maxim/tiny_mcp'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files =
    IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) { |ls|
      ls.readlines("\x0", chomp: true).reject { |f|
        (f == gemspec) || f.start_with?(*%w[bin/ test/ .git .github Gemfile])
      }
    }

  spec.require_paths = ['lib']
end
