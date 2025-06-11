# frozen_string_literal: true

require 'rails/generators'

module TinyMcp
  class ToolGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('../templates', __FILE__)
    
    desc 'Creates a new MCP tool in your Rails application'
    
    def create_tool_file
      # Ensure the tool name is in snake_case
      file_name = name.underscore
      class_name = file_name.camelize
      
      # Create the directory if it doesn't exist
      tools_path = 'app/mcp_tools'
      FileUtils.mkdir_p(tools_path) unless File.directory?(tools_path)
      
      # Create the tool file
      tool_path = File.join(tools_path, "#{file_name}.rb")
      
      # Check if the file already exists
      if File.exist?(tool_path)
        say_status :error, "Tool #{file_name} already exists at #{tool_path}", :red
        exit 1
      end
      
      # Generate the tool template
      template_content = <<~RUBY
        # frozen_string_literal: true
        
        class #{class_name} < TinyMCP::Tool
          name '#{file_name}'
          desc 'Description of what this tool does'
          arg :required_arg, :string, 'Description of required argument'
          opt :optional_arg, :string, 'Description of optional argument'
          
          def call(required_arg:, optional_arg: nil)
            # Your implementation here
            "You passed: \#{required_arg} and \#{optional_arg || 'no optional arg'}"
          end
        end
      RUBY
      
      # Write the file
      create_file tool_path, template_content
      
      say_status :create, "Created new MCP tool at #{tool_path}", :green
      say "\nTo use this tool, edit the file with your implementation.", :green
      say "Then you can serve your MCP tools with: rake tiny_mcp:serve", :green
    end
  end
end

