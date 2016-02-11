root_location = File.expand_path("../../", __FILE__)
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
require "yast/rspec"
require "fileutils"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
  # for coverage we need to load all ruby files
  Dir["#{root_location}/library/*/src/{module,lib}/**/*.rb"].each { |f| require_relative f }
  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
  end
end

