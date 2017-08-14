root_location = File.expand_path("../../", __FILE__)
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
require "yast/rspec"
require "fileutils"
require "pathname"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  src_location = File.expand_path("../../src", __FILE__)
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

FIXTURES_PATH = Pathname.new(File.dirname(__FILE__)).join("fixtures")

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
