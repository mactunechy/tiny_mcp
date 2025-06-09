# frozen_string_literal: true

require 'test_helper'
require 'stringio'



class TinyMCPTest < Minitest::Test
  class TestToolClass < TinyMCP::Tool; end

  def test_that_it_has_a_version_number
    refute_nil ::TinyMCP::VERSION
  end

  # Prop Data Class Tests
  def test_prop_creation
    prop = TinyMCP::Prop.new(:name, :string, 'Name of the item', true)
    assert_equal :name, prop.name
    assert_equal :string, prop.type
    assert_equal 'Name of the item', prop.desc
    assert_equal true, prop.req
  end

  def test_prop_to_h
    prop = TinyMCP::Prop.new(:age, :number, 'Age in years', false)
    expected = { type: :number, description: 'Age in years' }
    assert_equal expected, prop.to_h
  end

  # Definition Class Tests
  def test_definition_initialization
    definition = TinyMCP::Definition.new('Foo')
    assert_equal [], definition.props
    assert_equal 'Foo', definition.name
    assert_nil definition.desc
  end

  def test_definition_setting_attributes
    definition = TinyMCP::Definition.new('Foo')
    definition.name = 'test_tool'
    definition.desc = 'A test tool'

    assert_equal 'test_tool', definition.name
    assert_equal 'A test tool', definition.desc
  end

  def test_definition_adding_props
    definition = TinyMCP::Definition.new('calculator')
    definition.desc = 'Basic calculator'

    prop1 = TinyMCP::Prop.new(:x, :number, 'First number', true)
    prop2 = TinyMCP::Prop.new(:y, :number, 'Second number', true)
    prop3 = TinyMCP::Prop.new(:precision, :number, 'Decimal precision', false)

    definition.props << prop1
    definition.props << prop2
    definition.props << prop3

    assert_equal 3, definition.props.length
  end

  def test_definition_to_h
    definition = TinyMCP::Definition.new('greet')
    definition.desc = 'Greets a person'

    definition.props << TinyMCP::Prop[:name, :string, 'Name to greet', true]
    definition.props << TinyMCP::Prop[:title, :string, 'Optional title', false]

    expected = {
      name: 'greet',
      description: 'Greets a person',
      inputSchema: {
        type: 'object',
        properties: {
          name: { type: :string, description: 'Name to greet' },
          title: { type: :string, description: 'Optional title' }
        },
        required: [:name]
      }
    }

    assert_equal expected, definition.to_h
  end

  # Tool Base Class Tests
  def test_tool_class_name
    assert_equal 'TestToolClass', TestToolClass.mcp.name
  end

  def test_tool_inheritance_creates_definition
    test_tool_class = Class.new(TinyMCP::Tool)
    assert_instance_of TinyMCP::Definition, test_tool_class.mcp
    refute_nil test_tool_class.mcp
  end

  def test_tool_dsl_methods
    calculator_tool_class = Class.new(TinyMCP::Tool) do
      name 'calculator'
      desc 'Performs basic calculations'
      arg :x, :number, 'First operand'
      arg :y, :number, 'Second operand'
      opt :operation, :string, 'Operation to perform'
    end

    assert_equal 'calculator', calculator_tool_class.mcp.name
    assert_equal 'Performs basic calculations', calculator_tool_class.mcp.desc
    assert_equal 3, calculator_tool_class.mcp.props.length

    # Check required args
    x_prop = calculator_tool_class.mcp.props[0]
    assert_equal :x, x_prop.name
    assert_equal true, x_prop.req

    # Check optional args
    op_prop = calculator_tool_class.mcp.props[2]
    assert_equal :operation, op_prop.name
    assert_equal false, op_prop.req
  end

  def test_tool_call_raises_error_when_not_overridden
    abstract_tool_class = Class.new(TinyMCP::Tool) do
      name 'abstract'
      desc 'Should not be called directly'
    end

    tool = abstract_tool_class.new
    assert_raises(RuntimeError) { tool.call }
  end

  def test_tool_with_implementation
    greeter_tool_class = Class.new(TinyMCP::Tool) do
      name 'greeter'
      desc 'Greets people'
      arg :name, :string, 'Name to greet'

      def call(name:)
        "Hello, #{name}!"
      end
    end

    tool = greeter_tool_class.new
    assert_equal "Hello, Alice!", tool.call(name: 'Alice')
  end

  # Server Initialization Tests
  def test_server_initialization_with_defaults
    server = TinyMCP::Server.new

    # Test instance variables via handle_request
    request = { 'jsonrpc' => '2.0', 'id' => 1, 'method' => 'initialize' }
    response = server.send(:handle_request, request)

    assert_equal '2024-11-05', response[:result][:protocolVersion]
    assert_equal 'ruby-tinymcp-server', response[:result][:serverInfo][:name]
    assert_equal({ tools: {} }, response[:result][:capabilities])
  end

  def test_server_initialization_with_custom_values
    custom_tool_class = Class.new(TinyMCP::Tool) do
      name 'custom'
      desc 'Custom tool'
    end

    server = TinyMCP::Server.new(
      custom_tool_class,
      protocol_version: '2024-12-01',
      server_name: 'my-server',
      server_version: '2.0.0',
      capabilities: { tools: { custom: true } }
    )

    request = { 'jsonrpc' => '2.0', 'id' => 1, 'method' => 'initialize' }
    response = server.send(:handle_request, request)

    assert_equal '2024-12-01', response[:result][:protocolVersion]
    assert_equal 'my-server', response[:result][:serverInfo][:name]
    assert_equal({ tools: { custom: true } }, response[:result][:capabilities])
  end

  def test_server_creates_tool_instances
    tool1_class = Class.new(TinyMCP::Tool) do
      name 'tool1'
      desc 'First tool'
    end

    tool2_class = Class.new(TinyMCP::Tool) do
      name 'tool2'
      desc 'Second tool'
    end

    server = TinyMCP::Server.new(tool1_class, tool2_class)
    tools = server.instance_variable_get(:@tools)

    assert_equal 2, tools.length
    assert_instance_of tool1_class, tools[0]
    assert_instance_of tool2_class, tools[1]
  end

  # Server Request Handling Tests
  def test_initialize_method
    server = TinyMCP::Server.new
    request = { 'jsonrpc' => '2.0', 'id' => 1, 'method' => 'initialize' }
    response = server.send(:handle_request, request)

    assert_equal '2.0', response[:jsonrpc]
    assert_equal 1, response[:id]
    assert response[:result][:protocolVersion]
    assert response[:result][:capabilities]
    assert response[:result][:serverInfo]
  end

  def test_tools_list_method
    list_tool1_class = Class.new(TinyMCP::Tool) do
      name 'list_tool1'
      desc 'First listing tool'
      arg :param1, :string, 'Parameter 1'
    end

    list_tool2_class = Class.new(TinyMCP::Tool) do
      name 'list_tool2'
      desc 'Second listing tool'
    end

    server = TinyMCP::Server.new(list_tool1_class, list_tool2_class)
    request = { 'jsonrpc' => '2.0', 'id' => 2, 'method' => 'tools/list' }
    response = server.send(:handle_request, request)

    assert_equal 2, response[:result][:tools].length

    tool1 = response[:result][:tools].find { |t| t[:name] == 'list_tool1' }
    assert tool1
    assert_equal 'First listing tool', tool1[:description]
    assert tool1[:inputSchema]
  end

  def test_tools_call_valid_tool
    add_tool_class = Class.new(TinyMCP::Tool) do
      name 'add'
      desc 'Adds two numbers'
      arg :x, :number, 'First number'
      arg :y, :number, 'Second number'

      def call(x:, y:)
        x + y
      end
    end

    server = TinyMCP::Server.new(add_tool_class)
    request = {
      'jsonrpc' => '2.0',
      'id' => 3,
      'method' => 'tools/call',
      'params' => {
        'name' => 'add',
        'arguments' => { 'x' => 5, 'y' => 3 }
      }
    }

    response = server.send(:handle_request, request)

    assert_equal '2.0', response[:jsonrpc]
    assert_equal 3, response[:id]
    assert_equal [{ type: 'text', text: '8' }], response[:result][:content]
  end

  def test_tools_call_nonexistent_tool
    server = TinyMCP::Server.new
    request = {
      'jsonrpc' => '2.0',
      'id' => 4,
      'method' => 'tools/call',
      'params' => {
        'name' => 'nonexistent',
        'arguments' => {}
      }
    }

    response = server.send(:handle_request, request)

    assert response[:error]
    assert_equal(-32602, response[:error][:code])
    assert_match(/Unknown tool: nonexistent/, response[:error][:message])
  end

  def test_tools_call_with_error
    error_tool_class = Class.new(TinyMCP::Tool) do
      name 'error_tool'
      desc 'Tool that raises an error'

      def call
        raise 'Something went wrong!'
      end
    end

    server = TinyMCP::Server.new(error_tool_class)
    request = {
      'jsonrpc' => '2.0',
      'id' => 5,
      'method' => 'tools/call',
      'params' => {
        'name' => 'error_tool',
        'arguments' => {}
      }
    }

    response = server.send(:handle_request, request)

    assert response[:error]
    assert_equal(-32603, response[:error][:code])
    assert_match(/Something went wrong!/, response[:error][:message])
  end

  def test_unknown_method
    server = TinyMCP::Server.new
    request = { 'jsonrpc' => '2.0', 'id' => 6, 'method' => 'unknown/method' }
    response = server.send(:handle_request, request)

    assert response[:error]
    assert_equal(-32601, response[:error][:code])
    assert_equal 'Method not found', response[:error][:message]
  end

  # Error Handling Tests
  def test_error_types
    server = TinyMCP::Server.new

    # Test each error type
    error_types = {
      invalid_json: [-32700, 'Invalid JSON'],
      invalid_request: [-32600, 'Invalid request'],
      method_not_found: [-32601, 'Method not found'],
      invalid_params: [-32602, 'Invalid params'],
      internal: [-32603, 'Internal error']
    }

    error_types.each do |type, (code, message)|
      error = server.send(:error_for, { 'id' => 1 }, type)
      assert_equal code, error[:error][:code]
      assert_equal message, error[:error][:message]
    end
  end

  def test_error_with_custom_message
    server = TinyMCP::Server.new
    error =
      server.send(:error_for, { 'id' => 1 }, :internal, 'Custom error message')

    assert_equal(-32603, error[:error][:code])
    assert_equal 'Custom error message', error[:error][:message]
  end

  # Integration Tests
  def test_full_request_response_cycle
    echo_tool_class = Class.new(TinyMCP::Tool) do
      name 'echo'
      desc 'Echoes the input'
      arg :message, :string, 'Message to echo'

      def call(message:)
        message
      end
    end

    # Capture STDOUT
    old_stdout = $stdout
    $stdout = StringIO.new

    # Mock STDIN
    input = StringIO.new
    input.puts \
      '{"jsonrpc":"2.0","id":1,"method":"tools/call",' \
      '"params":{"name":"echo","arguments":{"message":"Hello"}}}'

    input.rewind
    old_stdin = $stdin
    $stdin = input

    server = TinyMCP::Server.new(echo_tool_class)

    # Run one iteration
    begin
      input_line = $stdin.gets
      request = JSON.parse(input_line.strip)
      response = server.send(:handle_request, request)
      $stdout.puts JSON.generate(response)
      $stdout.flush
    rescue
    end

    # Restore IO
    $stdin = old_stdin
    output = $stdout.string
    $stdout = old_stdout

    response = JSON.parse(output.strip)
    assert_equal 'Hello', response['result']['content'][0]['text']
  end

  # Edge Cases
  def test_tool_with_no_parameters
    no_param_tool_class = Class.new(TinyMCP::Tool) do
      name 'no_param'
      desc 'Tool with no parameters'

      def call
        'No parameters needed'
      end
    end

    server = TinyMCP::Server.new(no_param_tool_class)
    request = {
      'jsonrpc' => '2.0',
      'id' => 1,
      'method' => 'tools/call',
      'params' => {
        'name' => 'no_param',
        'arguments' => {}
      }
    }

    response = server.send(:handle_request, request)
    assert_equal 'No parameters needed', response[:result][:content][0][:text]
  end

  def test_tool_with_only_optional_parameters
    optional_tool_class = Class.new(TinyMCP::Tool) do
      name 'optional'
      desc 'Tool with only optional parameters'
      opt :greeting, :string, 'Optional greeting'
      opt :punctuation, :string, 'Optional punctuation'

      def call(greeting: 'Hello', punctuation: '!')
        "#{greeting} World#{punctuation}"
      end
    end

    server = TinyMCP::Server.new(optional_tool_class)

    # Call with no arguments
    request = {
      'jsonrpc' => '2.0',
      'id' => 1,
      'method' => 'tools/call',
      'params' => {
        'name' => 'optional',
        'arguments' => {}
      }
    }

    response = server.send(:handle_request, request)
    assert_equal 'Hello World!', response[:result][:content][0][:text]

    # Call with some arguments
    request['params']['arguments'] = { 'greeting' => 'Hi' }
    response = server.send(:handle_request, request)
    assert_equal 'Hi World!', response[:result][:content][0][:text]
  end

  def test_nil_request_id
    server = TinyMCP::Server.new
    request = { 'jsonrpc' => '2.0', 'id' => nil, 'method' => 'tools/list' }
    response = server.send(:handle_request, request)

    assert_nil response[:id]
    assert response[:result]
  end

  def test_missing_request_id
    server = TinyMCP::Server.new
    request = { 'jsonrpc' => '2.0', 'method' => 'tools/list' }
    response = server.send(:handle_request, request)

    assert_nil response[:id]
    assert response[:result]
  end

  def test_empty_tool_list
    server = TinyMCP::Server.new
    request = { 'jsonrpc' => '2.0', 'id' => 1, 'method' => 'tools/list' }
    response = server.send(:handle_request, request)

    assert_equal [], response[:result][:tools]
  end

  def test_string_keys_converted_to_symbols
    symbol_tool_class = Class.new(TinyMCP::Tool) do
      name 'symbol_test'
      desc 'Tests string to symbol conversion'
      arg :test_param, :string, 'Test parameter'

      def call(test_param:)
        "Received: #{test_param}"
      end
    end

    server = TinyMCP::Server.new(symbol_tool_class)
    request = {
      'jsonrpc' => '2.0',
      'id' => 1,
      'method' => 'tools/call',
      'params' => {
        'name' => 'symbol_test',
        'arguments' => { 'test_param' => 'value' }
      }
    }

    response = server.send(:handle_request, request)
    assert_equal 'Received: value', response[:result][:content][0][:text]
  end

  # Multi-modal Content Tests
  def test_tool_returning_array_of_content_items
    multi_content_tool_class = Class.new(TinyMCP::Tool) do
      name 'multi_content'
      desc 'Returns multiple content items'
      arg :content_type, :string, 'Type of content to return'

      def call(content_type:)
        case content_type
        when 'multiple_text'
          [
            { type: 'text', text: 'First text item' },
            { type: 'text', text: 'Second text item' },
            { type: 'text', text: 'Third text item' }
          ]
        when 'mixed'
          [
            { type: 'text', text: 'Some text content' },
            { type: 'image',
              data: 'base64-encoded-image-data',
              mimeType: 'image/png' },
            { type: 'text', text: 'More text after image' }
          ]
        end
      end
    end

    server = TinyMCP::Server.new(multi_content_tool_class)
    
    # Test multiple text content
    request = {
      'jsonrpc' => '2.0',
      'id' => 1,
      'method' => 'tools/call',
      'params' => {
        'name' => 'multi_content',
        'arguments' => { 'content_type' => 'multiple_text' }
      }
    }

    response = server.send(:handle_request, request)
    content = response[:result][:content]
    
    assert_equal 3, content.length
    assert_equal 'First text item', content[0][:text]
    assert_equal 'Second text item', content[1][:text]
    assert_equal 'Third text item', content[2][:text]
    content.each { |item| assert_equal 'text', item[:type] }
  end

  def test_tool_returning_mixed_content_types
    mixed_tool_class = Class.new(TinyMCP::Tool) do
      name 'mixed_content'
      desc 'Returns mixed content types'

      def call
        [
          { type: 'text', text: 'Here is some text' },
          { type: 'image',
            mimeType: 'image/png',
            data: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42' \
            'mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==' },
          { type: 'text', text: 'And more text after the image' },
          { type: 'resource',
            uri: 'file:///path/to/resource.txt',
            text: 'Resource reference' }
        ]
      end
    end

    server = TinyMCP::Server.new(mixed_tool_class)
    request = {
      'jsonrpc' => '2.0',
      'id' => 1,
      'method' => 'tools/call',
      'params' => {
        'name' => 'mixed_content',
        'arguments' => {}
      }
    }

    response = server.send(:handle_request, request)
    content = response[:result][:content]
    
    assert_equal 4, content.length
    
    # Check text content
    assert_equal 'text', content[0][:type]
    assert_equal 'Here is some text', content[0][:text]
    
    # Check image content
    assert_equal 'image', content[1][:type]
    assert_equal 'image/png', content[1][:mimeType]
    assert_equal 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42' \
                 'mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
                 content[1][:data]
    
    # Check second text content
    assert_equal 'text', content[2][:type]
    assert_equal 'And more text after the image', content[2][:text]
    
    # Check resource content
    assert_equal 'resource', content[3][:type]
    assert_equal 'file:///path/to/resource.txt', content[3][:uri]
    assert_equal 'Resource reference', content[3][:text]
  end

  def test_tool_returning_empty_array
    empty_tool_class = Class.new(TinyMCP::Tool) do
      name 'empty_content'
      desc 'Returns empty content array'

      def call
        []
      end
    end

    server = TinyMCP::Server.new(empty_tool_class)
    request = {
      'jsonrpc' => '2.0',
      'id' => 1,
      'method' => 'tools/call',
      'params' => {
        'name' => 'empty_content',
        'arguments' => {}
      }
    }

    response = server.send(:handle_request, request)
    content = response[:result][:content]
    
    assert_equal [], content
    assert_equal 0, content.length
  end

  def test_tool_returning_single_item_array
    single_tool_class = Class.new(TinyMCP::Tool) do
      name 'single_content'
      desc 'Returns single content item in array'
      arg :message, :string, 'Message to return'

      def call(message:)
        [{ type: 'text', text: message }]
      end
    end

    server = TinyMCP::Server.new(single_tool_class)
    request = {
      'jsonrpc' => '2.0',
      'id' => 1,
      'method' => 'tools/call',
      'params' => {
        'name' => 'single_content',
        'arguments' => { 'message' => 'Single item message' }
      }
    }

    response = server.send(:handle_request, request)
    content = response[:result][:content]
    
    assert_equal 1, content.length
    assert_equal 'text', content[0][:type]
    assert_equal 'Single item message', content[0][:text]
  end
end
