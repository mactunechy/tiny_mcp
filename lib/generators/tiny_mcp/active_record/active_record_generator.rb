# frozen_string_literal: true

require 'rails/generators/base'
require 'tiny_mcp/rails/generators/active_record_generator'

module TinyMcp
  module Generators
    # Rails generator wrapper for TinyMCP::Rails::Generators::ActiveRecordGenerator
    class ActiveRecordGenerator < TinyMCP::Rails::Generators::ActiveRecordGenerator
    end
  end
end

