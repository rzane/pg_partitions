require 'test_helper'

class CopyIndiciesTest < PgPartitions::TestCase
  def test_copy_indicies
    migrate Create, AddPartition, AddIndex do
      assert_equal [], index_names(:comments_2016)

      migrate CopyIndicies
      assert_equal ['index_comments_2016_on_body'], index_names(:comments_2016)
    end
  end

  def test_index_already_exists
    migrate Create, AddIndex, AddPartition do
      migrate CopyIndicies
      assert_equal ['comments_2016_body_idx'], index_names(:comments_2016)
    end
  end

  def test_indexes_out_of_sync
    migrate Create, AddPartition, AddConflictingIndexes do
      assert_raises PgPartitions::ConflictingIndexError do
        migrate CopyIndicies
      end
    end
  end

  private

  def index_names(name)
    conn.indexes(name).map(&:name)
  end
end
