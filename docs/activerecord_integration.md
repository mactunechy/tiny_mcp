# ActiveRecord Integration for TinyMCP

This guide explains how to use TinyMCP with Rails' ActiveRecord models to create safe, read-only tools for AI assistants.

## Overview

TinyMCP's ActiveRecord integration allows you to:

1. Expose your models as MCP tools for AI assistants
2. Control which fields are exposed
3. Limit the number of records returned
4. Skip large text/binary fields to avoid token bloat
5. Create explicit tool files with implementations

## Getting Started

### Option 1: Using the Generator

The easiest way is to use the provided generator which automatically exposes models and creates tool files:

```bash
# Expose specific models
rails generate tiny_mcp:active_record User Post Comment

# Or expose all models at once
rails generate tiny_mcp:active_record
```

This will:
1. Add the `expose_mcp :read_only` directive to each model
2. Create an initializer that registers dynamic tools for these models
3. Generate tool files in `app/mcp_tools/` for each model

### Option 2: Using the DSL Directly

You can also manually add the `expose_mcp` macro to your models:

```ruby
class User < ApplicationRecord
  expose_mcp :read_only, 
             limit: 50,  # Maximum records to return
             only: [:id, :name, :email],  # Only include these fields
             skip_large_fields: true  # Skip text/binary fields
end
```

Then use the model_tool generator to create the tool files:

```bash
# Generate tool files for specific exposed models
rails generate tiny_mcp:model_tool User Post Comment

# Generate tool files for all exposed models
rails generate tiny_mcp:model_tool
```

## Generated Tool Implementation

The generated tool files include implementations for all these read-only operations:

- `find`: Find a record by ID
- `find_by`: Find a record by attributes
- `where`: Find records matching conditions
- `first`: Get the first record
- `last`: Get the last record
- `count`: Count records matching criteria

Each operation respects the configuration options (limits, field filtering) that you set in the `expose_mcp` macro.

## Example Usage

Once generated, AI assistants can use these tools like this:

```
# Find by ID
assistant calls user_query with operation=find, params="1"

# Find by attributes
assistant calls user_query with operation=find_by, params={"email":"user@example.com"}

# Query with where
assistant calls user_query with operation=where, params={"age_gt":30}

# First/last records
assistant calls user_query with operation=first
assistant calls user_query with operation=last

# Count records
assistant calls user_query with operation=count
```

## Sample Implementation

You can find a sample implementation of a generated tool in `/examples/user_query_tool.rb`. Note that the class name follows Rails naming conventions, so a tool for the `User` model would have the class name `UserQuery` (not `UserQueryTool`).

## Troubleshooting

If the generator doesn't create tool files with the proper implementation:

1. Make sure you have the `expose_mcp` macro in your model first
2. Try running the `model_tool` generator separately:
   ```bash
   rails generate tiny_mcp:model_tool
   ```
3. Check for any errors in the Rails console
