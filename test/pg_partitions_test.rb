require 'test_helper'

class PgPartitionsTest < Minitest::Test
  class SetupComments < ActiveRecord::Migration[5.1]
    include PgPartitions

    def change
      create_table :comments do |t|
        t.string :body, index: true
        t.integer :year
      end

      add_partition :comments, :comments_2016, check: 'year = 2016'

      add_partition_trigger :comments, :comments_by_year, [
        { if: 'NEW.year = 2016', insert: :comments_2016 }
      ]

      add_partition :comments, :comments_2017, check: 'year = 2017'

      reversible do |dir|
        dir.up do
          update_partition_trigger :comments, :comments_by_year, [
            { if: 'NEW.year = 2016', insert: :comments_2016 },
            { elsif: 'NEW.year = 2017', insert: :comments_2017 },
            { else: "RAISE EXCEPTION 'Missing partition for year: %', NEW.year;" }
          ]
        end
      end
    end
  end

  class Comment < ActiveRecord::Base
  end

  class Trigger < ActiveRecord::Base
    self.primary_key = :trigger_name
    self.table_name  = 'information_schema.triggers'
  end

  def setup
    migrate SetupComments
  end

  def teardown
    if conn.table_exists? :comments
      migrate SetupComments, revert: true
    end
  end

  def test_partitions_exist
    assert_equal %w(comments comments_2016 comments_2017), conn.tables.sort
  end

  def test_partition_columns
    assert_equal columns_for(:comments), columns_for(:comments_2016)
  end

  def test_partition_indexes
    assert_equal indexes_for(:comments), indexes_for(:comments_2016)
  end

  def test_insert_trigger_table
    trigger = Trigger.find(:comments_by_year_insert)
    assert_equal 'comments', trigger.event_object_table
  end

  def test_insert_trigger_routine
    trigger = Trigger.find(:comments_by_year_insert)
    assert_equal 'EXECUTE PROCEDURE comments_by_year_insert()', trigger.action_statement
  end

  def test_delete_trigger_table
    trigger = Trigger.find(:comments_by_year_delete)
    assert_equal 'comments', trigger.event_object_table
  end

  def test_delete_trigger_routine
    trigger = Trigger.find(:comments_by_year_delete)
    assert_equal 'EXECUTE PROCEDURE comments_by_year_delete()', trigger.action_statement
  end

  def test_trigger_routing
    comment1 = Comment.create!(year: 2016)
    comment2 = Comment.create!(year: 2017)

    assert_equal [comment1.id], ids_for(:comments_2016)
    assert_equal [comment2.id], ids_for(:comments_2017)
  end

  def test_partitioning_all_data
    comment1 = Comment.create!(year: 2016)
    comment2 = Comment.create!(year: 2017)

    assert_equal [comment1.id, comment2.id], ids_for(:comments)
  end

  def test_invalid_data
    assert_raises ActiveRecord::StatementInvalid do
      Comment.create!(year: 2011)
    end
  end

  private

  def ids_for(name)
    Comment.from(name.to_s).pluck("#{name}.id").sort
  end

  def indexes_for(name)
    conn.indexes(name).map(&:columns)
  end

  def columns_for(name)
    conn.columns(name).map(&:name)
  end

  def migrate(*args)
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.run(*args)
    end
  end

  def conn
    ActiveRecord::Base.connection
  end
end
