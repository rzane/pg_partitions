require 'test_helper'

class AddPartitionTest < PgPartitions::TestCase
  def setup
    migrate Create, AddPartition
  end

  def teardown
    rollback AddPartition, Create
  end

  def test_partitions_exist
    expected = ['comments', 'comments_2016', 'comments_2017']
    assert_equal expected, conn.tables.sort
  end

  def test_partition_schema
    comments_cols = conn.columns('comments').map(&:name)
    comments_2016_cols = conn.columns('comments_2016').map(&:name)

    assert_equal comments_cols, comments_2016_cols
  end
end
