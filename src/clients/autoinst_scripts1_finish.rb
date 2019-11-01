# File:
#  autoinst_scripts1_finish.ycp
#
# Module:
#  Step of base installation finish
#
# Authors:
#  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  class AutoinstScripts1FinishClient < Client
    def main
      textdomain "autoinst"

      Yast.import "AutoinstScripts"
      Yast.import "AutoInstall"
      Yast.import "Installation"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("starting autoinst_scripts1_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        return {
          "steps" => 1,
          # progress step title
          "title" => _(
            "Executing autoinstall scripts in the installation environment..."
          ),
          "when"  => [:autoinst, :autoupg]
        }
      elsif @func == "Write"
        AutoinstScripts.Write("chroot-scripts", false)
        AutoInstall.Finish(Installation.destdir)
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("autoinst_scripts1_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::AutoinstScripts1FinishClient.new.main
