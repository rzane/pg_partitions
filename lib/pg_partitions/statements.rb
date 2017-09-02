module PgPartitions
  module Statements
    class Partition < Struct.new(:table, :check)
      def to_sql
        "(LIKE #{table} INCLUDING ALL, CHECK (#{check})) INHERITS (#{table})"
      end
    end

    class If < Struct.new(:conditions)
      def to_sql
        lines = conditions.map do |opts|
          if opts.key? :if
            build_condition :if, opts
          elsif opts.key? :elsif
            build_condition :elsif, opts
          else opts.key? :else
            "ELSE\n  #{opts[:else]}"
          end
        end

        lines << 'END IF;'
        lines.join "\n"
      end

      private

      def build_condition(key, opts)
        then_sql = opts.fetch :then do
          "INSERT INTO #{opts.fetch(:insert)} VALUES(NEW.*) RETURNING * INTO result;"
        end

        "#{key.to_s.upcase} (#{opts[key]}) THEN\n  #{then_sql}"
      end
    end

    class InsertFunction < Struct.new(:table, :name, :body)
      def to_sql
        <<~SQL
          CREATE FUNCTION #{name}()
          RETURNS TRIGGER AS $$
          DECLARE
            result #{table}%rowtype;
          BEGIN
          #{body.to_sql.indent(2)}
            RETURN result;
          END;
          $$
          LANGUAGE plpgsql;
        SQL
      end
    end

    class DeleteFunction < Struct.new(:table, :name)
      def to_sql
        <<~SQL
          CREATE FUNCTION #{name}()
          RETURNS TRIGGER AS $$
          DECLARE
            r #{table}%rowtype;
          BEGIN
            DELETE FROM ONLY #{table} WHERE id = NEW.id RETURNING * INTO r;
            RETURN r;
          END;
          $$
          LANGUAGE plpgsql;
        SQL
      end
    end

    class Trigger < Struct.new(:table, :name, :event)
      def to_sql
        <<~SQL
          CREATE TRIGGER #{name}
          #{event} ON #{table}
          FOR EACH ROW EXECUTE PROCEDURE #{name}();
        SQL
      end
    end
  end
end
