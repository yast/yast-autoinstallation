# File:  modules/AutoinstImage.ycp
# Package:  Auto-installation
# Summary:  Process Auto-Installation Images
# Author:  Uwe Gansert <uwe.gansert@suse.de>
#
# $Id$
require "yast"

module Yast
  class AutoinstImageClass < Module
    def main
      textdomain "autoinst"

      Yast.import "Progress"
      Yast.import "AutoinstConfig"
      Yast.import "URL"
      Yast.import "AutoinstSoftware"

      Yast.include self, "autoinstall/io.rb"
    end

    def getScript
      ret = false
      if Ops.get_string(AutoinstSoftware.image, "script_location", "") != ""
        urltok = URL.Parse(
          Ops.get_string(AutoinstSoftware.image, "script_location", "")
        )
        scheme = Ops.get_string(urltok, "scheme", "default")
        host = Ops.get_string(urltok, "host", "")
        filepath = Ops.get_string(urltok, "path", "")
        ret = Get(scheme, host, filepath, "/tmp/image.sh")
      elsif Ops.get_string(AutoinstSoftware.image, "script_source", "") != ""
        SCR.Write(
          path(".target.string"),
          "/tmp/image.sh",
          Ops.get_string(AutoinstSoftware.image, "script_source", "")
        )
        ret = true
      end
      ret
    end

    def runScript
      params = Builtins.mergestring(
        Ops.get_list(AutoinstSoftware.image, "script_params", []),
        " "
      )
      Convert.to_integer(
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat(
            "/bin/sh -x /tmp/image.sh %1 > /tmp/ayast_image.log 2>&1",
            params
          )
        )
      )
    end

    publish function: :getScript, type: "boolean ()"
    publish function: :runScript, type: "integer ()"
  end

  AutoinstImage = AutoinstImageClass.new
  AutoinstImage.main
end
