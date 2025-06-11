# frozen_string_literal: true

require 'tiny_mcp/version'
require 'json'
require 'shellwords'

# Load Rails integration if Rails is defined
require 'tiny_mcp/rails' if defined?(Rails)

module TinyMCP
  Prop = Data.define(:name, :type, :desc, :req) do
    def to_h = { type: type, description: desc }
  end

  class Definition
    attr_accessor :name, :desc, :props
    def initialize(name)
      @name = name
      @props = []
    end

    def to_h
      {
        name:,
        description: desc,
        inputSchema: {
          type: 'object',
          properties: props.map { [_1.name, _1.to_h] }.to_h,
          required: props.select(&:req).map(&:name)
        }
      }
    end
  end

  class Tool
    class << self
      attr_accessor :mcp
      alias __modname name

      def inherited(base)
        base.mcp = Definition.new(base.__modname&.split('::')&.last)
      end

      def name(string) = mcp.name = string
      def desc(string) = mcp.desc = string
      def arg(*args) = mcp.props << Prop[*args, true]
      def opt(*args) = mcp.props << Prop[*args, false]
    end

    def call = raise 'Override in subclass'
  end

  class Server
    ERROR_TYPES = {
      invalid_json:     [-32700, 'Invalid JSON'].freeze,
      invalid_request:  [-32600, 'Invalid request'].freeze,
      method_not_found: [-32601, 'Method not found'].freeze,
      invalid_params:   [-32602, 'Invalid params'].freeze,
      internal:         [-32603, 'Internal error'].freeze
    }.freeze

    def initialize *tools,
      protocol_version: '2024-11-05',
      server_name:      'ruby-tinymcp-server',
      server_version:   '1.0.0',
      capabilities:     { tools: {} }


      @tool_defs = tools.map { [_1.mcp.name, _1.mcp.to_h] }.to_h
      @tools = tools.map(&:new)

      @protocol_version = protocol_version
      @server_name      = server_name
      @server_version   = server_version
      @capabilities     = capabilities
    end

    def run
      loop do
        input = STDIN.gets
        break if input.nil?

        request =
          begin
            JSON.parse(input.strip)
          rescue
            puts error_for({'id' => nil}, :invalid_json)
            STDOUT.flush
            next
          end

        response = handle_request(request)

        puts JSON.generate(response)
        STDOUT.flush
      end
    end

    private

    def handle_request(request)
      case request['method']
      when 'initialize'
        response_for request,
          protocolVersion: @protocol_version,
          capabilities: @capabilities,
          serverInfo: { name: @server_name, version: @server_version }
      when 'tools/list'
        response_for request, tools: @tool_defs.values
      when 'tools/call'
        handle_tool_call request
      else
        error_for(request, :method_not_found)
      end
    end

    def handle_tool_call(request)
      name = request.dig('params', 'name')
      tool = @tools.find { _1.class.mcp.name == name }

      if !tool
        return error_for(request, :invalid_params, "Unknown tool: #{name}")
      end

      args = request.dig('params', 'arguments')&.transform_keys(&:to_sym)

      begin
        result = tool.call(**args)

        result.is_a?(Array) ?
          response_for(request, content: result) :
          response_for(request, content: [{ type: 'text', text: result.to_s }])
      rescue => e
        error_for(request, :internal, e.full_message(highlight: false))
      end
    end

    def error_for(request, type, message = ERROR_TYPES[type][1])
      code = ERROR_TYPES[type][0]
      { jsonrpc: '2.0', id: request['id'], error: { code:, message: } }
    end

    def response_for(request, **hash)
      { jsonrpc: '2.0', id: request['id'], result: hash }
    end
  end

  def self.serve(*args, **kwargs) = Server.new(*args, **kwargs).run
end
