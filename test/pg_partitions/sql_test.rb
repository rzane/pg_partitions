require 'test_helper'

class PgPartitions::SQLTest < Minitest::Test
  def test_sql_if
    statement = PgPartitions::SQL::If.new([
      { if: 'NEW.id = 1', insert: :foos },
      { elsif: 'NEW.id = 2', then: "RETURN 2;" },
      { else: 'RETURN 3;' }
    ])

    expected = <<~SQL
      IF (NEW.id = 1) THEN
        INSERT INTO foos VALUES(NEW.*) RETURNING * INTO result;
      ELSIF (NEW.id = 2) THEN
        RETURN 2;
      ELSE
        RETURN 3;
      END IF;
    SQL

    assert_equal expected, statement.to_sql
  end

  def test_insert_function
    statement = PgPartitions::SQL::InsertFunction.new(
      :foo,
      :bar,
      'RETURN 5;'
    )

    expected = <<~SQL
      CREATE FUNCTION bar()
      RETURNS TRIGGER AS $$
      DECLARE
        result foo%rowtype;
      BEGIN
        RETURN 5;
        RETURN result;
      END;
      $$
      LANGUAGE plpgsql;
    SQL

    assert_equal expected, statement.to_sql
  end
end
