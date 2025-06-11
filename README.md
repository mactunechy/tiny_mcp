# TinyMCP

A tiny Ruby implementation of the Model Context Protocol (MCP) that makes it easy to create and serve tools locally for AI assistants.

## Installation

```bash
gem install tiny_mcp
```

## Usage

Create tools by inheriting from `TinyMCP::Tool`:

```ruby
#!/usr/bin/env ruby
require 'tiny_mcp'

class WeatherTool < TinyMCP::Tool
  name 'get_weather'
  desc 'Get current weather for a city'
  arg :city, :string, 'City name' # required
  opt :units, :string, 'Temperature units (c/f)' # optional

  def call(city:, units: 'c')
    # Your implementation here
    "Weather in #{city}: 20°C, sunny"
  end
end

class TimeTool < TinyMCP::Tool
  name 'get_time'
  desc 'Get current time'
  opt :timezone, :string, 'Timezone name'

  def call(timezone: 'UTC')
    Time.now.getlocal(timezone)
  end
end

# Serve multiple tools
TinyMCP.serve(WeatherTool, TimeTool, server_name: 'my_tool')
```

You can put this in a `bin/mcp` file for example, and make it executable:

```bash
chmod +x bin/mcp
```

Then add it to Claude Code:

```bash
claude mcp add my-mcp bin/mcp
```

The server reads JSON-RPC requests from stdin and writes responses to stdout.

See [examples/](examples/) for more.

## Rails Integration

TinyMCP can be easily integrated with Rails applications. When you include TinyMCP in a Rails app, it automatically adds Rails-specific functionality.

To use TinyMCP with Rails:

```bash
# Add to your Gemfile
gem 'tiny_mcp'

# Generate the Rails integration
rails generate tiny_mcp:install
```

This sets up:

- An MCP controller to handle requests in your Rails app
- A directory for your MCP tools
- Rake tasks for managing tools

### ActiveRecord Integration

TinyMCP provides a simple DSL to expose your ActiveRecord models safely to AI tools:

```ruby
class User < ApplicationRecord
  # Make this model available as a read-only tool
  expose_mcp :read_only, limit: 50, only: [:id, :name, :email]
 end
```

You can also generate tools for multiple models at once:

```bash
# Expose specific models
rails generate tiny_mcp:active_record User Post Comment

# Expose all models
rails generate tiny_mcp:active_record
```

See [Rails Integration Documentation](lib/tiny_mcp/rails/README.md) for more details.

## Multiple results and different formats

By default TinyMCP assumes you're returning `text` from your call function. If you want to return image, audio, or a bunch of different results, wrap your return value in an array, and TinyMCP will treat your return value as the whole `content` body.

Don't forget that binary data such as images and audio needs to be Base64-encoded.

```ruby
require 'base64'

class MultiModalTool < TinyMCP::Tool
  name 'get_different_formats'
  desc 'Get results in different formats'

  def call
    [
      {
        type: 'text',
        text: 'This is a text response'
      },
      {
        type: 'image',
        mimeType: 'image/png',
        data: Base64.strict_encode64(File.binread('image.png'))
      },
      {
        type: 'audio',
        mimeType: 'audio/mpeg',
        data: Base64.strict_encode64(File.binread('audio.mp3'))
      }
    ]
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/maxim/tiny_mcp. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/maxim/tiny_mcp/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TinyMCP project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/maxim/tiny_mcp/blob/main/CODE_OF_CONDUCT.md).
