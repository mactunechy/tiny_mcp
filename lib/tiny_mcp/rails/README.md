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

## Exposing ActiveRecord Models

TinyMCP provides a simple way to expose your ActiveRecord models for read-only operations in AI assistants, which is useful for safely querying data without risking memory issues or excessive token usage.

### Manually Adding the DSL

To expose a model, add the `expose_mcp` macro to your model class:

```ruby
class User < ApplicationRecord
  # Expose this model with read-only operations
  expose_mcp :read_only, 
             limit: 50,  # Maximum records to return
             only: [:id, :name, :email],  # Only include these fields
             skip_large_fields: true  # Skip large text/binary fields
             
  # ... rest of your model ...
end
```

This will create a TinyMCP tool called `user_query` that can be used to query the User model with these operations:
- `find`: Find a record by ID
- `find_by`: Find a record by attributes
- `where`: Find records matching conditions
- `first`: Get the first record
- `last`: Get the last record
- `count`: Count records matching criteria

### Using the Generator

You can also use the generator to expose models:

```bash
# Expose specific models
rails generate tiny_mcp:active_record User Post Comment

# Expose all models
rails generate tiny_mcp:active_record
```

The generator will:
1. Add the `expose_mcp :read_only` directive to each model
2. Create an initializer that registers dynamic tools for these models
3. Generate explicit tool files in `app/mcp_tools` for each model

If you want to generate only the tool files for already exposed models, you can use:

```bash
# Generate tool files for specific exposed models
rails generate tiny_mcp:model_tool User Post Comment

# Generate tool files for all exposed models
rails generate tiny_mcp:model_tool
```

Each generated tool file will include implementations for all the read-only operations mentioned above.

### Options

The `expose_mcp` macro accepts these options:

- `limit`: Maximum number of records to return (default: 100)
- `only`: Array of fields to include (whitelist)
- `except`: Array of fields to exclude (blacklist)
- `skip_large_fields`: Automatically skip text and binary fields (default: true)

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

