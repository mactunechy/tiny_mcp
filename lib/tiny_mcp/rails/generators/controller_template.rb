# frozen_string_literal: true

class McpController < ApplicationController
  include TinyMCP::Rails::Controller
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }
  
  # POST /mcp
  def handle
    # Parse the JSON request
    begin
      request_data = JSON.parse(request.body.read)
    rescue JSON::ParserError
      return render json: error_response(nil, -32700, 'Invalid JSON'), status: :bad_request
    end
    
    # Process the MCP request with all available tools
    response = process_mcp_request(request_data, *TinyMCP::Rails.load_tools)
    
    # Return the response
    render json: response
  end
  
  private
  
  def error_response(id, code, message)
    {
      jsonrpc: '2.0',
      id: id,
      error: {
        code: code,
        message: message
      }
    }
  end
end

