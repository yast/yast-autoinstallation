root_location = File.expand_path("../../", __FILE__)
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
require "yast/rspec"
require "fileutils"

if ENV["COVERAGE"]
  STDERR.puts "COVERAGE is disabled because when requiring some modules (like AutoinstPartition) "\
    "errors are raised in other YaST components."
end

FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')
