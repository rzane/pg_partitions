require 'active_support/core_ext/string'

require 'pg_partitions/version'
require 'pg_partitions/statements'

module PgPartitions
  def add_partition(table, name, check:)
    statement = Statements::Partition.new(table, check)
    create_table(name, id: false, options: statement.to_sql)
  end

  def add_partition_trigger(table, name, conditions)
    insert_conditions = Statements::If.new(conditions)
    insert_function   = Statements::InsertFunction.new(table, name, insert_conditions)
    insert_trigger    = Statements::Trigger.new(table, name, 'BEFORE INSERT')

    delete_function   = Statements::DeleteFunction.new(table, "#{name}_delete")
    delete_trigger    = Statements::Trigger.new(table, "#{name}_delete", 'AFTER INSERT')

    reversible do |dir|
      dir.up do
        execute insert_function.to_sql
        execute insert_trigger.to_sql

        execute delete_function.to_sql
        execute delete_trigger.to_sql
      end

      dir.down do
        drop_partition_trigger(table, name)
      end
    end
  end

  def drop_partition_trigger(table, name)
    execute "DROP TRIGGER #{name} ON #{table}"
    execute "DROP FUNCTION #{name}()"
    execute "DROP TRIGGER #{name}_delete ON #{table}"
    execute "DROP FUNCTION #{name}_delete()"
  end
end
