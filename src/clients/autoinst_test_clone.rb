module Yast
  class AutoinstTestCloneClient < Client
    def main
      textdomain "autoinst"
      Yast.import "XML"
      Yast.import "Wizard"
      Yast.import "Popup"
      Yast.import "Mode"
      Mode.SetMode("autoinst_config")
      Yast.include self, "autoinstall/xml.rb"
      Wizard.CreateDialog
      Popup.ShowFeedback(
        _("Reading configuration data..."),
        _("This may take a while")
      )

      profileSetup
      @client = ""

      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @client = Convert.to_string(WFM.Args(0))
      end

      WFM.CallFunction(Ops.add(@client, "_auto"), ["Read"])
      @result = WFM.CallFunction(Ops.add(@client, "_auto"), ["Export"])
      @current = {}
      Ops.set(@current, @client, @result)
      XML.YCPToXMLFile(:profile, @current, Ops.add(@client, ".xml"))
      Popup.ClearFeedback

      Wizard.CloseDialog

      nil
    end
  end
end

Yast::AutoinstTestCloneClient.new.main
