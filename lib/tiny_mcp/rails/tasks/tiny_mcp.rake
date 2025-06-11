# frozen_string_literal: true

# Load ActiveRecord tasks if ActiveRecord is defined
load 'tiny_mcp/rails/tasks/active_record.rake' if defined?(ActiveRecord)

namespace :tiny_mcp do
  desc 'Serve MCP tools from your Rails application'
  task serve: :environment do
    server_name = ENV['SERVER_NAME'] || Rails.application.class.module_parent_name.underscore
    server_version = ENV['SERVER_VERSION'] || '1.0.0'
    protocol_version = ENV['PROTOCOL_VERSION'] || '2024-11-05'
    
    puts "Starting TinyMCP server for #{Rails.application.class.module_parent_name}..."
    puts "Server name: #{server_name}"
    puts "Protocol version: #{protocol_version}"
    puts "Serving from: #{Rails.root.join(Rails.application.config.tiny_mcp.tools_path)}"
    puts "Press Ctrl+C to stop"
    
    begin
      TinyMCP.serve_rails(
        server_name: server_name,
        server_version: server_version,
        protocol_version: protocol_version
      )
    rescue Interrupt
      puts "\nShutting down TinyMCP server..."
    end
  end
  
  desc 'Generate a new MCP tool'
  task :generate, [:name] => :environment do |_, args|
    name = args[:name]
    if name.blank?
      puts "Error: Please provide a name for the tool"
      puts "Example: rake tiny_mcp:generate[weather_tool]"
      exit 1
    end
    
    # Convert to snake_case if not already
    file_name = name.underscore
    class_name = file_name.camelize
    
    # Create the tool file
    tool_path = Rails.root.join(Rails.application.config.tiny_mcp.tools_path, "#{file_name}.rb")
    if File.exist?(tool_path)
      puts "Error: Tool #{file_name} already exists at #{tool_path}"
      exit 1
    end
    
    # Generate the tool template
    template = <<~RUBY
      # frozen_string_literal: true
      
      class #{class_name} < TinyMCP::Tool
        name '#{file_name}'
        desc 'Description of what this tool does'
        arg :required_arg, :string, 'Description of required argument'
        opt :optional_arg, :string, 'Description of optional argument'
        
        def call(required_arg:, optional_arg: nil)
          # Your implementation here
          "You passed: #{required_arg} and #{optional_arg || 'no optional arg'}"
        end
      end
    RUBY
    
    # Write the file
    File.write(tool_path, template)
    puts "Created new MCP tool at #{tool_path}"
  end
  
  desc 'List all available MCP tools'
  task list: :environment do
    tools = TinyMCP::Rails.load_tools
    if tools.empty?
      puts "No MCP tools found in #{Rails.application.config.tiny_mcp.tools_path}"
      puts "Generate a tool with: rake tiny_mcp:generate[tool_name]"
    else
      puts "Found #{tools.size} MCP tools:"
      tools.each do |tool_class|
        puts "- #{tool_class.mcp.name}: #{tool_class.mcp.desc || 'No description'}"
        puts "  Arguments:"
        tool_class.mcp.props.each do |prop|
          req = prop.req ? "(required)" : "(optional)"
          puts "  - #{prop.name} (#{prop.type}): #{prop.desc} #{req}"
        end
        puts ""
      end
    end
  end
end

