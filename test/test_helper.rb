$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pg_partitions'
require 'active_record'
require 'minitest/autorun'

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  database: 'pg_partitions_test'
)
