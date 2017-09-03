require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

namespace :db do
  task :setup do
    system 'createdb pg_partitions_dev'
    system 'createdb pg_partitions_test'
  end

  task :reset do
    system 'dropdb pg_partitions_dev'
    system 'dropdb pg_partitions_test'
    Rake::Task['db:setup'].invoke
  end
end

task default: :test
