$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pg_partitions'
require 'active_record'
require_relative 'migrations'
require 'minitest/autorun'

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  database: 'pg_partitions'
)

class Comment < ActiveRecord::Base
end

class Trigger < ActiveRecord::Base
  self.primary_key = :trigger_name
  self.table_name  = 'information_schema.triggers'
end

class PgPartitions::TestCase < Minitest::Test
  include Migrations

  private

  def migrate(*args)
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.run(*args)
    end

    if block_given?
      begin
        yield
      ensure
        rollback(*args.reverse)
      end
    end
  end

  def rollback(*args)
    migrate(*args, revert: true)
  end

  def conn
    ActiveRecord::Base.connection
  end
end
