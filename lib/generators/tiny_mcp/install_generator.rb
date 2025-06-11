# frozen_string_literal: true

require 'rails/generators'

module TinyMcp
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('../../../tiny_mcp/rails/generators', __FILE__)
    
    desc 'Creates an MCP controller and adds routes for handling MCP requests'
    
    def create_controller
      # Create controllers directory if it doesn't exist
      FileUtils.mkdir_p('app/controllers') unless File.directory?('app/controllers')
      
      # Copy the controller template
      template 'controller_template.rb', 'app/controllers/mcp_controller.rb'
      
      puts "Created MCP controller at app/controllers/mcp_controller.rb"
    end
    
    def create_tools_directory
      # Create tools directory
      tools_path = 'app/mcp_tools'
      FileUtils.mkdir_p(tools_path) unless File.directory?(tools_path)
      
      puts "Created MCP tools directory at #{tools_path}"
    end
    
    def add_routes
      route_code = "post '/mcp', to: 'mcp#handle'"
      
      # Check if the route already exists
      if File.read('config/routes.rb').include?(route_code)
        puts "Route already exists"
      else
        route route_code
        puts "Added MCP route: #{route_code}"
      end
    end
    
    def show_next_steps
      puts ""
      puts "==== TinyMCP for Rails Setup Complete ===="
      puts "To generate a new MCP tool:"
      puts "  $ rails g tiny_mcp:tool NAME"
      puts "  or"
      puts "  $ rake tiny_mcp:generate[NAME]"
      puts ""
      puts "To list all available MCP tools:"
      puts "  $ rake tiny_mcp:list"
      puts ""
      puts "To serve MCP tools:"
      puts "  $ rake tiny_mcp:serve"
      puts ""
      puts "Your MCP endpoint is available at:"
      puts "  POST /mcp"
      puts "======================================="
    end
  end
end

