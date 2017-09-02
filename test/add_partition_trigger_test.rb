require 'test_helper'

class AddPartitionTriggerTest < PgPartitions::TestCase
  def setup
    migrate Create, AddPartition, AddPartitionTrigger
  end

  def teardown
    rollback AddPartitionTrigger, AddPartition, Create
  end

  def test_trigger_table
    trigger = Trigger.find(:comments_by_year)
    assert_equal 'comments', trigger.event_object_table
  end

  def test_trigger_routine
    trigger = Trigger.find(:comments_by_year)
    assert_equal 'EXECUTE PROCEDURE comments_by_year()', trigger.action_statement
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
end
