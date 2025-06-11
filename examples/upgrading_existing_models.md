# Upgrading Existing Rails Models for TinyMCP

This example shows how to add TinyMCP read-only capabilities to your existing Rails models.

## Option 1: Using the Generator

The easiest way is to use the provided generator which automatically adds the `expose_mcp` macro to your models:

```bash
# Expose specific models
rails generate tiny_mcp:active_record User Post Comment

# Or expose all models at once
rails generate tiny_mcp:active_record
```

This will add the `expose_mcp :read_only` line to each model file and create an initializer that creates tools for these models.

## Option 2: Manually Adding the DSL

You can also manually add the `expose_mcp` macro to your models:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # Add this line to expose the model to TinyMCP
  expose_mcp :read_only, limit: 50, only: [:id, :name, :email]
  
  # Rest of your model stays the same
  has_many :posts
  has_secure_password
  validates :email, presence: true, uniqueness: true
  # ...
end
```

Then create an initializer to register the tools:

```ruby
# config/initializers/tiny_mcp_models.rb

# Create TinyMCP tools for exposed ActiveRecord models
Rails.application.config.after_initialize do
  # Create the tools when ActiveRecord models are loaded
  model_tools = TinyMCP::Rails::ActiveRecord.create_tools
  
  # Add the tools to TinyMCP's available tools
  TinyMCP::Rails.mcp_tools ||= []
  TinyMCP::Rails.mcp_tools.concat(model_tools)
end
```

## Configuring Memory-Intensive Queries

To prevent memory issues with large datasets or token-expensive outputs:

1. **Set appropriate limits**:
   ```ruby
   expose_mcp :read_only, limit: 20  # Limit to 20 records max
   ```

2. **Filter only necessary fields**:
   ```ruby
   expose_mcp :read_only, only: [:id, :name, :email]  # Only include these fields
   ```

3. **Exclude large fields**:
   ```ruby
   expose_mcp :read_only, except: [:description, :content, :metadata]
   ```

4. **Automatically skip large field types**:
   ```ruby
   expose_mcp :read_only, skip_large_fields: true  # Skip text/binary/json fields
   ```

## Using the Generated Tools

Once exposed, your models will be available as TinyMCP tools with these operations:

- `find`: Find a record by ID
- `find_by`: Find a record by attributes
- `where`: Find records matching conditions
- `first`: Get the first record
- `last`: Get the last record
- `count`: Count records matching criteria

Example of an AI assistant using the tool:

```
User: How many users do we have in our database?

AI: I'll check that for you.

[calls the user_query tool with operation=count]

We have 152 users in the database.

User: Find all posts with the word "AI" in the title

AI: Let me search for those posts.

[calls the post_query tool with operation=where, params={"title LIKE": "%AI%"}]

I found 5 posts with "AI" in the title:
1. "Introduction to AI" by John Smith
2. "AI in Healthcare" by Jane Doe
3. "The Future of AI" by Alice Johnson
4. "AI Ethics" by Bob Williams
5. "AI Programming Techniques" by Chris Brown
```

