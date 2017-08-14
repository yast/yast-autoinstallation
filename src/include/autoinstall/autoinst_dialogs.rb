# encoding: utf-8

# File:	modules/ProfileLocation.ycp
# Package:	Auto-installation
# Summary:	Process Auto-Installation Location
# Author:	Anas Nashif <nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallAutoinstDialogsInclude
    def initialize_autoinstall_autoinst_dialogs(include_target)
      textdomain "autoinst"
      Yast.import "Label"
      Yast.import "Popup"
    end

    # Shows a dialog when 'control file' can't be found
    # @param [String] original Original value
    # @return [String] new value
    def ProfileSourceDialog(original)
      helptext = _(
        "<p>\n" +
          "A profile for this machine could not be found or retrieved.\n" +
          "Check that you entered the correct location\n" +
          "on the command line and try again. Because of this error, you\n" +
          "can only enter a URL to a profile and not to a directory. If you\n" +
          "are using rules or host name-based control files, restart the\n" +
          "installation process and make sure the control files are accessible.</p>\n"
      )
      title = _("System Profile Location")

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HWeight(30, RichText(helptext)),
          HStretch(),
          HSpacing(1),
          HWeight(
            70,
            VBox(
              Heading(title),
              VSpacing(1),
              VStretch(),
              MinWidth(60,
                Left(TextEntry(Id(:uri), _("&Profile Location:"), original))
              ),
              VSpacing(1),
              VStretch(),
              HBox(
                PushButton(Id(:retry), Opt(:default), Label.RetryButton),
                PushButton(Id(:abort), Label.AbortButton)
              )
            )
          )
        )
      )

      uri = ""
      while true
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :abort && Popup.ConfirmAbort(:painless)
          break
        elsif ret == :retry
          uri = Convert.to_string(UI.QueryWidget(Id(:uri), :Value))
          if uri == ""
            next
          else
            break
          end
        end
      end

      UI.CloseDialog
      uri
    end



    # Disk selection dialog
    # @return [String] device
    def DiskSelectionDialog
      Builtins.y2milestone("Selecting disk manually....")
      devicegraph = Y2Storage::StorageManager.instance.y2storage_probed
      disks = devicegraph.disk_devices
      contents = Dummy()

      if !disks.empty?
        buttonbox = VBox()

        i = 0
        disks.each do |disk|
          tline = "&#{i+1}:    #{disk.basename}"
          # storage-ng
          sel = false
=begin
          sel = Storage.GetPartDisk == tname &&
            Storage.GetPartMode != "CUSTOM"
=end
          buttonbox << Left(RadioButton(Id(disk.name), tline, sel))
          i += 1
        end

        buttonbox = Builtins.add(buttonbox, VSpacing(0.8))


        # This dialog selects the target disk for the installation.
        # Below this label, all targets are listed that can be used as
        # installation target

        # heading text
        contents = Frame(
          _("Choose a hard disk"),
          RadioButtonGroup(
            Id(:options),
            VBox(VSpacing(0.4), HSquash(buttonbox), VSpacing(0.4))
          )
        )
      else
        contents = Label(_("No disks found."))
      end

      # There are several hard disks found. Linux is completely installed on
      # one hard disk - this selection is done here
      # "Preparing Hard Disk - Step 1" is the description of the dialog what to
      # do while the following locale is the help description
      # help part 1 of 1
      help_text = _(
        "<p>\n" +
          "All hard disks automatically detected on your system\n" +
          "are shown here. Select the hard disk on which to install &product;.\n" +
          "</p>"
      )
      buttons = HBox(
        PushButton(Id(:ok), Opt(:default), Label.OKButton),
        PushButton(Id(:abort), Label.AbortButton)
      )



      ask_device_dialog = HBox(
        VSpacing(15), # force dialog height
        VBox(
          HSpacing(30), # force help text width
          RichText(help_text)
        ),
        HSpacing(3),
        VBox(
          VSpacing(1),
          Heading(_("Hard Disk Selection")),
          contents,
          VStretch(),
          buttons
        ),
        HSpacing(3)
      )

      UI.OpenDialog(Opt(:decorated), ask_device_dialog)

      ret = nil
      option = ""
      begin
        ret = UI.UserInput
        Builtins.y2milestone("ret=%1", ret)
        if ret == :ok
          option = Convert.to_string(
            UI.QueryWidget(Id(:options), :CurrentButton)
          )
          Builtins.y2milestone("selected disk: %1", option)
          if option == nil
            # there is a selection from that one option has to be
            # chosen - at the moment no option is chosen
            Popup.Message(_("Select one of the options to continue."))
            ret = nil
          end
        end
      end until ret == :ok || ret == :abort

      UI.CloseDialog
      option
    end
  end
end
