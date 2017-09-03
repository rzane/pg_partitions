# PgPartitions

Partitioning postgres takes some doing. PgPartitions adds methods to your migrations to help you manage them.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pg_partitions'
```

And then execute:

    $ bundle

## Usage

Imagine you have a comments table with millions of rows and your queries are starting to be a bit slow. Postgres partitioning allows yo to divide your comments table into smaller tables.

In a migration, you'll first need to include `PgPartitions`.

```ruby
class PartitionComments < ActiveRecord::Migration[5.1]
  include PgPartitions

  def change
    # ...
  end
end
```

Let's assume we have a column called year that stores the year the comment was created. We can partition our table based on the value of that column:

```ruby
add_partition :comments, :comments_2016, check: 'year = 2016'
add_partition :comments, :comments_2017, check: 'year = 2017'
```

After we create our partitions, the query plan is going to change a little bit:

```ruby
Comment.all.explain
=> EXPLAIN for: SELECT "comments".* FROM "comments"
                               QUERY PLAN
------------------------------------------------------------------------
 Append  (cost=0.00..60.80 rows=4081 width=12)
   ->  Seq Scan on comments  (cost=0.00..0.00 rows=1 width=12)
   ->  Seq Scan on comments_2016  (cost=0.00..30.40 rows=2040 width=12)
   ->  Seq Scan on comments_2017  (cost=0.00..30.40 rows=2040 width=12)
```

See how it's querying our partitions in addition to the parent table? Now, watch what happens when we put a WHERE condition on the `year` column:

```ruby
Comment.where(year: 2016).explain
=> EXPLAIN for: SELECT "comments".* FROM "comments" WHERE "comments"."year" = $1 [["year", 2016]]
                              QUERY PLAN
----------------------------------------------------------------------
 Append  (cost=0.00..35.50 rows=11 width=12)
   ->  Seq Scan on comments  (cost=0.00..0.00 rows=1 width=12)
         Filter: (year = 2016)
   ->  Seq Scan on comments_2016  (cost=0.00..35.50 rows=10 width=12)
         Filter: (year = 2016)
```

Notice how it never looked at the `comments_2017` table? That's the magic of partitions.

Now, there's one remaining issue. When we insert data into the `comments` table, we need it to route to be inserted into a partition instead of the actual table. For that, we can create a trigger:

```ruby
add_partition_trigger :comments, :comments_by_year, [
  { if:    'NEW.year = 2016', insert: :comments_2016 },
  { elsif: 'NEW.year = 2017', insert: :comments_2017 },
  { else:  "RAISE EXECEPTION 'comments_by_year recieived an unexpected value: %', NEW.year;" }
]
```

If the new record has a `year` of 2016, it'll be inserted into the `comments_2016` table. If the `year` is 2017, it'll be inserted into the `comments_2017` table. Otherwise, the trigger will throw an error.

Now, imagine a year goes by and you need to add another partition for `2018`. You'll need to add the partition and update the trigger:

```ruby
add_partition :comments, :comments_2018, check: 'NEW.year = 2018'

update_partition_trigger :comments, :comments_by_year, [
  { if:    'NEW.year = 2016', insert: :comments_2016 },
  { elsif: 'NEW.year = 2017', insert: :comments_2017 },
  { elsif: 'NEW.year = 2018', insert: :comments_2018 },
  { else:  "RAISE EXECEPTION 'comments_by_year recieived an unexpected value: %', NEW.year;" }
]
```

## Caveats

* You'll have to set `config.active_record.schema_format = :sql`. PgPartition doesn't support the use of `schema.rb`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rzane/pg_partitions.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

