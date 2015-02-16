# encoding: utf-8

# File:
#	modules/AutoinstClass.ycp
#
# Module:
#	AutoinstClass
#
# Summary:
#	This module handles the configuration for auto-installation
#
# Authors:
#	Anas Nashif <nashif@suse.de>
#
# $Id$
require "yast"

module Yast
  class AutoinstClassClass < Module
    def main
      Yast.import "AutoinstConfig"
      Yast.import "XML"
      Yast.import "Summary"
      Yast.include self, "autoinstall/xml.rb"

      @classDir = AutoinstConfig.classDir
      @ClassConf = "/etc/autoinstall"
      @profile_conf = []
      @Profiles = []
      @Classes = []
      @deletedClasses = []
      @confs = []
      @class_file = "classes.xml"
      @classPath = File.join(@classDir, @class_file)

      AutoinstClass()
    end

    # find a profile path
    # @param string profile name
    # @return [String] profile Path
    def findPath(name, _class)
      result = @confs.find { |c| c['name'] == name && c['class'] == _class } || {}
      result ||= { 'class' => '', 'name' => 'default' }
      File.join(@classDir, result['class'], result['name'])
    end

    # Read classes
    def Read
      if SCR.Read(path(".target.size"), @classPath) != -1
        # TODO: use XML module
        classes_map = Convert.to_map(SCR.Read(path(".xml"), @classPath))
        @Classes = classes_map['classes'] || []
      else
        @Classes = []
      end
      nil
    end


    #     we are doing some compatibility fixes here and move
    #     from one /etc/autoinstall/classes.xml to multiple
    #     classes.xml files, one for each repository
    def Compat
      if !class_file_exists? && compat_class_file_exists?
        Builtins.y2milestone("Compat: %1 not found but %2 exists",
                             @classPath, compact_class_file)
        new_classes_map = { 'classes' => read_old_classes }
        Builtins.y2milestone("creating %1", new_classes_map)
        XML.YCPToXMLFile(:class, new_classes_map, @classPath)
      end
      nil
    end

    # Change the directory of classes definitions
    #
    # AutoinstConfig#classDir= is called to set the new value
    # in the configuration.
    #
    # @param [String] Path of the new directory
    # @return nil
    def classDirChanged(newdir)
      AutoinstConfig.classDir = newdir
      @classDir = newdir
      @classPath = File.join(@classDir, @class_file)
      Compat()
      Read()
      nil
    end

    # Constructor
    # @return void

    def AutoinstClass
      classSetup
      Compat()
      Read()
      nil
    end





    # Merge Classes
    #

    def MergeClasses(configuration, base_profile, resultFileName)
      configuration = deep_copy(configuration)
      dontmerge_str = ""
      i = 1
      Builtins.foreach(AutoinstConfig.dontmerge) do |dm|
        dontmerge_str = Ops.add(
          dontmerge_str,
          Builtins.sformat(" --param dontmerge%1 \"'%2'\" ", i, dm)
        )
        i = Ops.add(i, 1)
      end
      tmpdir = AutoinstConfig.tmpDir
      _MergeCommand = Builtins.sformat(
        "/usr/bin/xsltproc --novalid --param replace \"'false'\" %1 --param with ",
        dontmerge_str
      )

      _MergeCommand = Ops.add(
        Ops.add(
          Ops.add(_MergeCommand, "\"'"),
          findPath(
            Ops.get_string(configuration, "name", ""),
            Ops.get_string(configuration, "class", "")
          )
        ),
        "'\"  "
      )
      _MergeCommand = Ops.add(
        Ops.add(
          Ops.add(Ops.add(Ops.add(_MergeCommand, "--output "), tmpdir), "/"),
          resultFileName
        ),
        " "
      )
      _MergeCommand = Ops.add(
        _MergeCommand,
        " /usr/share/autoinstall/xslt/merge.xslt "
      )
      _MergeCommand = Ops.add(Ops.add(_MergeCommand, base_profile), " ")


      Builtins.y2milestone("Merge command: %1", _MergeCommand)

      out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), _MergeCommand, {})
      )
      Builtins.y2milestone(
        "Merge stdout: %1, stderr: %2",
        Ops.get_string(out, "stdout", ""),
        Ops.get_string(out, "stderr", "")
      )
      deep_copy(out)
    end





    # Read files from class directories
    # @return [void]
    def Files
      @confs = []
      Builtins.foreach(@Classes) do |_class|
        files = Convert.convert(
          SCR.Read(
            path(".target.dir"),
            Ops.add(
              Ops.add(@classDir, "/"),
              Ops.get_string(_class, "name", "xxx")
            )
          ),
          :from => "any",
          :to   => "list <string>"
        )
        if files != nil
          Builtins.y2milestone(
            "Files in class %1: %2",
            Ops.get_string(_class, "name", "xxx"),
            files
          )
          tmp_confs = Builtins.maplist(files) do |file|
            conf = {}
            Ops.set(conf, "class", Ops.get_string(_class, "name", "xxx"))
            Ops.set(conf, "name", file)
            deep_copy(conf)
          end
          Builtins.y2milestone("Configurations: %1", tmp_confs)
          @confs = Convert.convert(
            Builtins.union(@confs, tmp_confs),
            :from => "list",
            :to   => "list <map>"
          )
        end
      end
      Builtins.y2milestone("Configurations: %1", @confs)
      nil
    end



    # Save Class definitions

    def Save
      Builtins.foreach(@deletedClasses) do |c|
        toDel = Builtins.sformat(
          "/bin/rm -rf %1/%2",
          AutoinstConfig.classDir,
          c
        )
        SCR.Execute(path(".target.bash"), toDel)
      end
      @deletedClasses = []
      tmp = { "classes" => @Classes }
      Builtins.y2debug("saving classes: %1", @classPath)
      XML.YCPToXMLFile(:class, tmp, @classPath)
    end



    # Import configuration

    def Import(settings)
      settings = deep_copy(settings)
      @profile_conf = deep_copy(settings)
      true
    end

    # Export configuration

    def Export
      deep_copy(@profile_conf)
    end

    # Configuration Summary

    def Summary
      summary = ""

      Builtins.foreach(@profile_conf) do |c|
        summary = Summary.AddHeader(
          summary,
          Ops.get_string(c, "class_name", "None")
        )
        summary = Summary.AddLine(
          summary,
          Ops.get_string(c, "configuration", "None")
        )
      end
      return Summary.NotConfigured if Builtins.size(summary) == 0
      summary
    end

    publish :variable => :classDir, :type => "string"
    publish :variable => :ClassConf, :type => "string"
    publish :variable => :profile_conf, :type => "list <map>"
    publish :variable => :Profiles, :type => "list"
    publish :variable => :Classes, :type => "list <map>"
    publish :variable => :deletedClasses, :type => "list <string>"
    publish :variable => :confs, :type => "list <map>"
    publish :function => :findPath, :type => "string (string, string)"
    publish :function => :Read, :type => "void ()"
    publish :function => :Compat, :type => "void ()"
    publish :function => :classDirChanged, :type => "void (string)"
    publish :function => :AutoinstClass, :type => "void ()"
    publish :function => :MergeClasses, :type => "map (map, string, string)"
    publish :function => :Files, :type => "void ()"
    publish :function => :Save, :type => "boolean ()"
    publish :function => :Import, :type => "boolean (list <map>)"
    publish :function => :Export, :type => "list <map> ()"
    publish :function => :Summary, :type => "string ()"

    # Checks if a classes.xml exists
    # @return [true,false] Returns true when present (false otherwise).
    def class_file_exists?
      SCR.Read(path(".target.size"), @classPath) > 0
    end

    # Checks if an old classes.xml exists
    # @return [true,false] Returns true when present (false otherwise).
    # @see compact_class_file
    def compat_class_file_exists?
      SCR.Read(path(".target.size"), compact_class_file) > 0
    end

    # Returns the path of the old classes.xml file
    # By default, it is called /etc/autoinstall/classes.xml.
    # @return [String] Path to the old classes.xml file.
    def compact_class_file
      File.join(@ClassConf, @class_file)
    end

    # Builds a map of classes to import from /etc/autoinstall/classes.xml
    # @return [Array<Hash>] Classes defined in the file.
    def read_old_classes
      old_classes_map = Convert.to_map(SCR.Read(path('.xml'), compact_class_file))
      old_classes = old_classes_map['classes'] || []
      old_classes.reduce([]) do |new_classes, _class|
        _class_path = File.join(@classDir, _class['name'] || '')
        Builtins.y2milestone("looking for %1", _class_path)
        new_classes << _class unless SCR.Read(path(".target.dir"), _class_path).nil?
        new_classes
      end
    end
  end

  AutoinstClass = AutoinstClassClass.new
  AutoinstClass.main
end
