module Migrations
  class Create < ActiveRecord::Migration[5.1]
    def change
      create_table :comments do |t|
        t.string :body
        t.integer :year
      end
    end
  end

  class AddPartition < ActiveRecord::Migration[5.1]
    include PgPartitions

    def change
      add_partition :comments, :comments_2017, check: 'year = 2017'
      add_partition :comments, :comments_2016, check: 'year = 2016'
    end
  end

  class AddPartitionTrigger < ActiveRecord::Migration[5.1]
    include PgPartitions

    def change
      add_partition_trigger :comments, :comments_by_year, [
        { if: 'NEW.year = 2017', insert: :comments_2017 },
        { elsif: 'NEW.year = 2016', insert: :comments_2016 },
        { else: "RAISE EXCEPTION 'Missing partition for year: %', NEW.year;" }
      ]
    end
  end
end
