require "installation/finish_client"

Yast.import "AutoinstFile"

module Y2Autoinstallation
  module Clients
    class AutoinstFilesFinish < ::Installation::FinishClient
      def title
        textdomain "autoinst"
        _("Writing configuration files ...")
      end

      def modes
        [:autoinst]
      end

      def write
        ::Yast::AutoinstFile.Write
      end
    end
  end
end
