require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  @table_name = nil
  @columns = nil
  @attributes

  def self.columns
    return @columns if @columns
    info = DBConnection.execute2(<<-SQL)
    SELECT
      *
    FROM
      #{table_name}
    SQL
    @columns = info.first.map(&:to_sym)
  end

  def self.finalize!
    columns.each do |column_name|
      define_method(column_name) do
        attributes[column_name]
      end

      define_method("#{column_name}=") do |val|
        attributes[column_name] = val
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ? @table_name : (self).to_s.tableize
  end

  def self.all
    full_database = DBConnection.execute(<<-SQL)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
    SQL

    parse_all(full_database)
  end

  def self.parse_all(results)
    result_array = []
    results.each do |hash_object|
      result_array  << self.new(hash_object)
    end
    result_array
  end

  def self.find(id)
    found = DBConnection.execute(<<-SQL)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = #{id}
    SQL
    parse_all(found).first
  end

  def initialize(params = {})
    params.each do |key, val|
      key = key.to_sym
      raise "unknown attribute '#{key}'" unless self.class.columns.include?(key)

      self.send("#{key}=".to_sym, val)

    end
  end

  def attributes
    @attributes || @attributes = {}
  end

  def attribute_values
    attributes.values
  end

  def insert
    col_names = self.class.columns.drop(1).join(", ")
    question_marks = ["?"] * attribute_values.length
    question_marks = "(#{question_marks.join(", ")})"

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        #{question_marks}
    SQL

    attributes[:id] = DBConnection.last_insert_row_id
  end

  def update

    set_row = self.class.columns.drop(1).map {|col| "#{col} = ?"}.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values.rotate(1))
      UPDATE
        #{self.class.table_name}
      SET
        #{set_row}
      WHERE
        id = ?
      SQL
  end

  def save
    id.nil? ? insert : update
  end
end
