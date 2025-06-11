# TinyMCP ActiveRecord Read-Only Integration

## Implementation Summary

We've added the following functionality to the TinyMCP gem to support read-only operations for Rails models:

1. **DSL for ActiveRecord Models**
   - Added a simple `expose_mcp` macro that can be added to ActiveRecord models
   - Supports options like `limit`, `only`, `except`, and `skip_large_fields` to control data exposure
   - Automatically handles memory-intensive fields by allowing filtering or auto-skipping large fields

2. **Dynamic Tool Creation**
   - Automatically creates TinyMCP tools for each exposed model
   - Each tool supports these operations: `find`, `find_by`, `where`, `first`, `last`, and `count`
   - All operations apply appropriate limits and field filtering to prevent memory issues

3. **Rails Generator**
   - Added `tiny_mcp:active_record` generator to automatically expose models
   - Can expose specific models or all models at once
   - Configurable via command-line options

4. **Rake Tasks**
   - Added `tiny_mcp:activerecord:expose` to expose specific models
   - Added `tiny_mcp:activerecord:expose_all` to expose all models
   - Added `tiny_mcp:activerecord:list` to list exposed models

5. **Documentation**
   - Updated README.md with information about the ActiveRecord integration
   - Created example code to demonstrate usage
   - Added detailed instructions in lib/tiny_mcp/rails/README.md

## How to Use

### Adding to a Model

```ruby
class User < ApplicationRecord
  expose_mcp :read_only, limit: 50, only: [:id, :name, :email]
 end
```

### Using the Generator

```bash
# Expose specific models
rails generate tiny_mcp:active_record User Post Comment

# Expose all models
rails generate tiny_mcp:active_record
```

### Using Rake Tasks

```bash
# Expose specific models
rake tiny_mcp:activerecord:expose[User,Post,Comment]

# Expose all models
rake tiny_mcp:activerecord:expose_all
```

## Next Steps

Possible future enhancements:

1. Support for other exposure modes beyond `:read_only`
2. More sophisticated query capabilities
3. Integration with authorization systems like Pundit or CanCanCan
4. Enhanced field type detection and handling
5. Pagination support for large datasets

