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

# mock missing YaST modules, they are needed by an early import call
module Yast
  class FileSystemsClass
    def default_subvol
      "@"
    end

    def read_default_subvol_from_target
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
