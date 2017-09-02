require "pg_partitions/version"
require 'active_support/core_ext/string'

module PgPartitions
  class ConflictingIndexError < StandardError
    def initialize(parent, child)
      @parent = parent
      @child = child

      super <<~MSG
        An index named #{parent.name} exists on both #{parent.table} and #{child.table},
        but they differ. You can resolve this issue by running:

          remove_index :#{child.table}, name: :#{child.name}
      MSG
    end
  end

  def add_partition(table, name, check:)
    options = "(LIKE #{table} INCLUDING ALL, CHECK (#{check})) " \
              "INHERITS (#{table})"

    create_table(name, id: false, options: options)
  end

  def add_partition_trigger(table, name, mappings)
    expressions = mappings.map do |opts|
      if opts.key? :if
        build_condition(:if, opts)
      elsif opts.key? :elsif
        build_condition(:elsif, opts)
      else opts.key? :else
        "ELSE\n  #{opts[:else]}"
      end
    end

    expressions << "END IF;"

    invoke = proc do
      execute <<~SQL
        CREATE FUNCTION #{name}()
        RETURNS TRIGGER AS $$
        DECLARE
          r #{table}%rowtype;
        BEGIN
        #{expressions.join("\n").indent(2)}
          RETURN r;
        END;
        $$
        LANGUAGE plpgsql;

        CREATE FUNCTION #{name}_delete()
        RETURNS TRIGGER AS $$
        DECLARE
          r #{table}%rowtype;
        BEGIN
          DELETE FROM ONLY #{table} WHERE id = NEW.id RETURNING * INTO r;
          RETURN r;
        END;
        $$
        LANGUAGE plpgsql;

        CREATE TRIGGER #{name}
        BEFORE INSERT ON #{table}
        FOR EACH ROW EXECUTE PROCEDURE #{name}();

        CREATE TRIGGER #{name}_delete
        AFTER INSERT ON #{table}
        FOR EACH ROW EXECUTE PROCEDURE #{name}_delete();
      SQL
    end

    reversible do |dir|
      dir.up(&invoke)

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

  def copy_indicies(from:, to:)
    parents = connection.indexes(from)

    arg_lists = to.flat_map do |table_name|
      children = connection.indexes(table_name)

      matches = parents.map do |index|
        [index, children.find { |i| i.columns == index.columns }]
      end

      matches.map do |parent, child|
        if child.nil?
          [table_name, parent.columns, index_options(parent)]
        elsif indexes_differ?(parent, child)
          raise ConflictingIndexError.new(parent, child)
        end
      end
    end

    reversible do |dir|
      dir.up do
        arg_lists.compact.each do |args|
          add_index(*args)
        end
      end

      dir.down do
        raise ActiveRecord::IrreversibleMigration
      end
    end
  end

  def index_options(index)
    %i(unique where length using type).reduce({}) do |acc, key|
      value = index.public_send(key)
      value ? acc.merge(key => value) : acc
    end
  end

  def indexes_differ?(a, b)
    a.to_h.except(:name, :table) != b.to_h.except(:name, :table)
  end

  private

  def build_condition(key, opts)
    then_sql = opts.fetch :then do
      "INSERT INTO #{opts.fetch(:insert)} VALUES(NEW.*)"
    end

    "#{key.to_s.upcase} (#{opts[key]}) THEN\n  #{then_sql} RETURNING * INTO r;"
  end
end
