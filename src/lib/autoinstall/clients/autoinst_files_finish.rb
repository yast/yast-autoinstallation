require "installation/finish_client"

Yast.import "AutoinstFile"
Yast.import "Mode"

module Y2Autoinstallation
  module Clients
    class AutoinstFilesFinish < ::Installation::FinishClient
      def title
        textdomain "autoinst"
        _("Writing configuration files ...")
      end

      def write
        ::Yast::AutoinstFile.Write if Mode.auto
      end
    end
  end
end
