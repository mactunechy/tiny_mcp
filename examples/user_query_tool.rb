# frozen_string_literal: true

# This is a sample template of a generated tool file for a User model
# This shows how all the read-only operations are implemented

# Tool for querying the User model
class UserQuery < TinyMCP::Tool
  name 'user_query'
  desc 'Query the User model with read-only operations'
  
  arg :operation, :string, "Operation to perform (find, find_by, where, first, last, count)"
  opt :params, :string, "Parameters for the operation in JSON format"
  opt :limit, :integer, "Maximum number of records to return"
  opt :fields, :string, "Comma-separated list of fields to include"
  
  def call(operation:, params: nil, limit: nil, fields: nil)
    # Process operation
    case operation.to_sym
    when :find
      handle_find(params, limit, fields)
    when :find_by
      handle_find_by(params, fields)
    when :where
      handle_where(params, limit, fields)
    when :first
      handle_first(fields)
    when :last
      handle_last(fields)
    when :count
      handle_count(params)
    else
      "Error: Unsupported operation '#{operation}'"
    end
  end
  
  private
  
  # Find a record by ID
  def handle_find(params, limit, fields)
    return "Error: 'params' is required for find operation" if params.blank?
    
    begin
      id = JSON.parse(params)
      record = User.find(id)
      format_record(record, fields)
    rescue => e
      "Error: #{e.message}"
    end
  end
  
  # Find a record by attributes
  def handle_find_by(params, fields)
    return "Error: 'params' is required for find_by operation" if params.blank?
    
    begin
      conditions = JSON.parse(params)
      record = User.find_by(conditions)
      record ? format_record(record, fields) : "No User found matching criteria"
    rescue => e
      "Error: #{e.message}"
    end
  end
  
  # Find records matching conditions
  def handle_where(params, limit, fields)
    return "Error: 'params' is required for where operation" if params.blank?
    
    begin
      conditions = JSON.parse(params)
      records = User.where(conditions)
      
      # Apply limit
      max_limit = User.tiny_mcp_exposure[:options][:limit]
      custom_limit = limit.present? ? [limit.to_i, max_limit].min : max_limit
      records = records.limit(custom_limit)
      
      format_collection(records, fields)
    rescue => e
      "Error: #{e.message}"
    end
  end
  
  # Get the first record
  def handle_first(fields)
    record = User.first
    record ? format_record(record, fields) : "No User records found"
  end
  
  # Get the last record
  def handle_last(fields)
    record = User.last
    record ? format_record(record, fields) : "No User records found"
  end
  
  # Count records matching criteria
  def handle_count(params)
    if params.present?
      begin
        conditions = JSON.parse(params)
        count = User.where(conditions).count
        "Found #{count} Users matching criteria"
      rescue => e
        "Error: #{e.message}"
      end
    else
      count = User.count
      "Total Users: #{count}"
    end
  end
  
  # Format a single record
  def format_record(record, fields)
    options = {}
    
    # Apply field filtering
    if fields.present?
      options[:only] = fields.split(',').map(&:strip).map(&:to_sym)
    else
      exposure_options = User.tiny_mcp_exposure[:options]
      options[:only] = exposure_options[:only] if exposure_options[:only].present?
      options[:except] = exposure_options[:except] if exposure_options[:except].present?
      
      # Skip large fields if configured
      if exposure_options[:skip_large_fields]
        large_field_types = [:text, :binary, :json, :jsonb]
        large_fields = User.columns.select { |c| large_field_types.include?(c.type) }.map(&:name).map(&:to_sym)
        options[:except] ||= []
        options[:except] += large_fields
      end
    end
    
    # Format the record as JSON
    result = record.as_json(options)
    JSON.pretty_generate(result)
  end
  
  # Format a collection of records
  def format_collection(records, fields)
    if records.any?
      formatted = records.map { |record| format_record(record, fields) }
      "Found #{records.size} Users:\n#{formatted.join("\n")}"
    else
      "No Users found matching criteria"
    end
  end
end
