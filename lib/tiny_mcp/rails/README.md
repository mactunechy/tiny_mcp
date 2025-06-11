# TinyMCP Rails Integration

This module provides an easy way to integrate TinyMCP with your Rails application. It adds generators, rake tasks, and controller support for serving Model Context Protocol (MCP) tools from your Rails app.

## Installation

1. Add this to your Gemfile:

```ruby
gem 'tiny_mcp'
```

2. Run the install generator:

```bash
rails generate tiny_mcp:install
```

This will:

- Create an MCP controller at `app/controllers/mcp_controller.rb`
- Create a directory for MCP tools at `app/mcp_tools`
- Add a route for handling MCP requests at `/mcp`

## Creating Tools

To create a new MCP tool, you can use either the generator or the rake task:

```bash
rails generate tiny_mcp:tool my_tool
```

or

```bash
rake tiny_mcp:generate[my_tool]
```

This will create a new MCP tool at `app/mcp_tools/my_tool.rb` with a basic template.

## Listing Tools

To see all available MCP tools in your Rails app:

```bash
rake tiny_mcp:list
```

## Serving Tools

To serve your MCP tools:

```bash
rake tiny_mcp:serve
```

This will start a server that listens for MCP requests on stdin and writes responses to stdout.

You can also use the MCP controller that was created during installation to handle MCP requests at `/mcp` in your Rails app.

## Using Rails Features in Your Tools

Since your tools are part of your Rails app, you can use all Rails features, such as ActiveRecord, ActionView, etc. in your tools.

Example of an MCP tool that uses ActiveRecord:

```ruby
class UserSearchTool < TinyMCP::Tool
  name 'search_users'
  desc 'Search for users by name or email'
  arg :query, :string, 'Search query'
  opt :limit, :integer, 'Maximum number of results'

  def call(query:, limit: 10)
    users = User.where('name LIKE ? OR email LIKE ?', "%#{query}%", "%#{query}%").limit(limit)
    
    users.map do |user|
      "#{user.name} (#{user.email})"
    end.join("\n")
  end
end
```

## Configuration

You can configure TinyMCP in your Rails application's configuration files:

```ruby
# config/application.rb or config/environments/*.rb
config.tiny_mcp.tools_path = 'app/mcp_tools' # default
```

This setting controls where TinyMCP looks for tool files.

