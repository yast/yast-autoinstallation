# encoding: utf-8

# File:  clients/inst_autoimage.ycp
# Package:  Auto-installation
# Author:      Anas Nashif <nashif@suse.de>
# Summary:  Imaging
#
# $Id$
module Yast
  class InstAutoimageClient < Client
    def main
      textdomain "autoinst"

      Yast.import "Installation"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "AutoinstImage"
      Yast.import "AutoinstSoftware"
      Yast.import "AutoinstScripts"
      Yast.import "AutoinstConfig"

      Yast.include self, "autoinstall/io.rb"

      AutoinstScripts.Write("postpartitioning-scripts", false)

      return :auto if !AutoinstSoftware.imaging

      @help_text = _("<p>\nPlease wait while the image is retrieved.</p>\n")
      @progress_stages = [_("Retrieve Image File"), _("Install image file")]

      @progress_descriptions = [
        _("Retrieving image file..."),
        _("Installing image file...")
      ]

      Progress.New(
        _("Installing image into system..."),
        "", # progress_title
        Builtins.size(@progress_stages), # progress bar length
        @progress_stages,
        @progress_descriptions,
        @help_text
      )

      Progress.NextStage

      # if (!AutoinstImage::Get(AutoinstSoftware::ft_module, Installation::destdir ))
      # {
      #    Report::Error(_("Error while retrieving image."));
      #    return `abort;
      # }

      until AutoinstImage.getScript
        Report.Error(
          Builtins.sformat(_("fetching image-script failed:\n%1"), @GET_error)
        )
      end

      while AutoinstImage.runScript != 0
        @output = Convert.to_string(
          SCR.Read(path(".target.string"), "/tmp/ayast_image.log")
        )
        Report.Error(
          Builtins.sformat(_("running image-script failed:\n%1"), @output)
        )
      end

      Progress.Finish

      :next
    end
  end
end

Yast::InstAutoimageClient.new.main
