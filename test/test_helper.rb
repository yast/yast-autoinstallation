ENV["Y2DIR"] = File.expand_path("../src", __dir__)

# make sure we run the tests in English locale
# (some tests check the output which is marked for translation)
ENV["LC_ALL"] = "en_US.UTF-8"

require "yast"
require "yast/rspec"
require "fileutils"
require "pathname"

RSpec.configure do |config|
  config.extend Yast::I18n # available in context/describe
  config.include Yast::I18n # available in it/let/before/around/after
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  src_location = File.expand_path("../src", __dir__)
  # track all ruby files under src
  SimpleCov.track_files("#{src_location}/**/*.rb")

  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
  end
end

TESTS_PATH = Pathname.new(File.dirname(__FILE__))
FIXTURES_PATH = TESTS_PATH.join("fixtures")

# mock missing YaST modules, they are needed by an early import call
module Yast
  class FileSystemsClass
    def default_subvol
      "@"
    end

    def read_default_subvol_from_target
      "@"
    end

    def default_subvol_from_product
      "@"
    end

    def GetAllFileSystems(_add_swap, _add_pseudo, _label)
      {}
    end
  end
  FileSystems = FileSystemsClass.new

  class KeyboardClass
    def dummy
      true
    end
  end
  Keyboard = KeyboardClass.new

  class TimezoneClass
    def dummy
      true
    end
  end
  Timezone = TimezoneClass.new
end

require "y2packager/medium_type"
require_relative "support/storage_helpers"

RSpec.configure do |c|
  c.include Y2Autoinstall::RSpec::StorageHelpers

  c.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  c.before do
    allow(Y2Packager::MediumType).to receive(:detect_medium_type).and_return(:standard)
  end
end
