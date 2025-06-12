# frozen_string_literal: true

require 'rails/generators/base'
require 'tiny_mcp/rails/generators/model_tool_generator'

module TinyMcp
  module Generators
    # Rails generator wrapper for TinyMCP::Rails::Generators::ModelToolGenerator
    class ModelToolGenerator < TinyMCP::Rails::Generators::ModelToolGenerator
    end
  end
end
