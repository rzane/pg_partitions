require 'test_helper'

class PgPartitionsTest < Minitest::Test
  class One < ActiveRecord::Migration[5.1]
    include PgPartitions

    def change
      create_table(:comments) { |t| t.integer :year }

      add_partition :comments, :comments_2017, check: 'year = 2017'
      add_partition :comments, :comments_2016, check: 'year = 2016'

      add_partition_trigger :comments, :comments_by_year, [
        { if: 'NEW.year = 2017', insert: :comments_2017 },
        { elsif: 'NEW.year = 2016', insert: :comments_2016 },
        { else: "RAISE EXCEPTION 'Missing partition for year: %', NEW.year;" }
      ]
    end
  end

  class Comment < ActiveRecord::Base
  end

  def setup
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.run One
    end

    @conn    = ActiveRecord::Base.connection
    @trigger = find_trigger('comments_by_year')
  end

  def teardown
    Comment.delete_all

    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.run One, revert: true
    end
  end

  def test_that_it_has_a_version_number
    assert PgPartitions::VERSION
  end

  def test_partitions_exist
    expected = ['comments', 'comments_2016', 'comments_2017']
    assert_equal expected, @conn.tables.sort
  end

  def test_partition_schema
    comments_cols = @conn.columns('comments').map(&:name)
    comments_2016_cols = @conn.columns('comments_2016').map(&:name)

    assert_equal comments_cols, comments_2016_cols
  end

  def test_trigger_table
    assert_equal 'comments', @trigger['event_object_table']
  end

  def test_trigger_routine
    assert_equal 'EXECUTE PROCEDURE comments_by_year()', @trigger['action_statement']
  end

  def test_trigger_source
  end

  def test_trigger_routing
    comment1 = Comment.create!(year: 2016)
    comment2 = Comment.create!(year: 2017)

    ids_2016 = Comment.from('comments_2016').pluck('comments_2016.id')
    ids_2017 = Comment.from('comments_2017').pluck('comments_2017.id')

    assert_equal [comment1.id], ids_2016
    assert_equal [comment2.id], ids_2017
  end

  def test_partitioning_all_data
    comment1 = Comment.create!(year: 2016)
    comment2 = Comment.create!(year: 2017)
    assert_equal [comment1.id, comment2.id], Comment.pluck(:id).sort
  end

  def trigger_raises_for_missing_partition
  end

  def test_synchronize_indexes
  end

  private

  def find_trigger(name)
    sql = <<~SQL
      SELECT * FROM information_schema.triggers t
      WHERE t.trigger_name = '#{name}';
    SQL

    @conn.execute(sql).first
  end
end
