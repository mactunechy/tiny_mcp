# frozen_string_literal: true

require 'tiny_mcp'

module TinyMCP
  module Rails
    # Rails integration for TinyMCP
    class Railtie < ::Rails::Railtie
      # Add Rake tasks when railtie is loaded
      rake_tasks do
        load 'tiny_mcp/rails/tasks/tiny_mcp.rake'
      end

      # Initialize configuration defaults
      config.tiny_mcp = ActiveSupport::OrderedOptions.new
      config.tiny_mcp.tools_path = 'app/mcp_tools'
      
      # After initialization setup
      initializer 'tiny_mcp.setup' do |app|
        # Make sure the tools directory exists
        tools_path = ::Rails.root.join(app.config.tiny_mcp.tools_path)
        FileUtils.mkdir_p(tools_path) unless File.directory?(tools_path)
      end
    end

    # Controller mixin for handling MCP requests in Rails controllers
    module Controller
      extend ActiveSupport::Concern

      # Process an MCP request and return the response
      # @param request [Hash] The MCP request
      # @param tools [Array<Class>] The tool classes to serve
      # @return [Hash] The MCP response
      def process_mcp_request(request, *tools)
        server = TinyMCP::Server.new(*tools)
        response = server.send(:handle_request, request)
        response
      end
    end

    # Helper to find and load all MCP tools in a Rails app
    # @return [Array<Class>] All tool classes in the app
    def self.load_tools
      tools_path = ::Rails.root.join(::Rails.application.config.tiny_mcp.tools_path)
      return [] unless File.directory?(tools_path)

      # Load all tool files
      Dir[File.join(tools_path, '**', '*.rb')].each do |file|
        require file
      end

      # Find all classes that inherit from TinyMCP::Tool
      tools = []
      ObjectSpace.each_object(Class) do |klass|
        tools << klass if klass < TinyMCP::Tool && klass != TinyMCP::Tool
      end
      tools
    end
  end

  # Add a method to TinyMCP module to serve tools from a Rails app
  def self.serve_rails(*tools, **kwargs)
    tools = Rails.load_tools if tools.empty?
    serve(*tools, **kwargs)
  end
end

