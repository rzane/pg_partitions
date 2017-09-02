require "pg_partitions/version"
require 'active_support/core_ext/string'

module PgPartitions
  def add_partition(table, name, check:)
    options = "(LIKE #{table} INCLUDING ALL, CHECK (#{check})) " \
              "INHERITS (#{table})"

    create_table(name, id: false, options: options)
  end

  def build_condition(key, opts)
    then_sql = opts.fetch :then do
      "INSERT INTO #{opts.fetch(:insert)} VALUES(NEW.*)"
    end

    "#{key.to_s.upcase} (#{opts[key]}) THEN\n  #{then_sql} RETURNING * INTO r;"
  end

  # Triggers
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

  # Index synchronization

  def synchronize_indexes(from:, to:)
    expected = index_statements_for(from)

    to.each do |table_name|
      actual = index_statements_for(table_name)

      (expected - actual).each do |statement|
        execute(statement)
      end
    end
  end

  def index_statements_for(table)
    execute <<~SQL
      SELECT pg_get_indexdef(idx.oid)||';'
      FROM pg_index ind
      JOIN pg_class idx on idx.oid = ind.indexrelid
      JOIN pg_class tbl on tbl.oid = ind.indrelid
      LEFT join pg_namespace ns ON ns.oid = tbl.relnamespace
      WHERE tbl.relname = #{table};
    SQL
  end
end
