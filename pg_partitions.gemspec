# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pg_partitions/version'

Gem::Specification.new do |spec|
  spec.name          = "pg_partitions"
  spec.version       = PgPartitions::VERSION
  spec.authors       = ["Ray Zane"]
  spec.email         = ["ray@promptworks.com"]

  spec.summary       = %q{ActiveRecord::Migration utility for creating partitions in PostgreSQL.}
  spec.homepage      = "https://github.com/rzane/pg_partitions"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "activerecord"
end
