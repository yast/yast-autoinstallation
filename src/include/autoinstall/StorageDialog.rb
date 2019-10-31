# encoding: utf-8

# File:  clients/autoinst_storage.ycp
# Package:  Autoinstallation Configuration System
# Summary:  Storage
# Authors:  Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallStorageDialogInclude
    def initialize_autoinstall_StorageDialog(include_target)
      textdomain "autoinst"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "String"
      Yast.import "AutoinstStorage"
      Yast.import "AutoinstPartPlan"

      Yast.include include_target, "autoinstall/common.rb"
      Yast.include include_target, "autoinstall/tree.rb"
      Yast.include include_target, "autoinstall/DriveDialog.rb"
      Yast.include include_target, "autoinstall/VolgroupDialog.rb"
      Yast.include include_target, "autoinstall/PartitionDialog.rb"
    end

    # Storage::GetTargetMap(); // initialize libstorage

    def startsWith(haystack, needle)
      Builtins.substring(haystack, 0, Builtins.size(needle)) == needle
    end

    # Displayed when tree is empty
    def EmptyDialog
      Label(Id(:treeinspect), _("Nothing selected"))
    end

    # Top level event handler
    #
    # Catches all events not handled by the currently active
    # subdialog (one of: Drive, Partition or LVM).
    #
    # The general idea is (like with dispatchMenuEvent()):
    #
    # When the user clicks on a button (Add { Drive, Partition,
    # LVM }, Remove):
    #
    #  1. the check() function on the currently active dialog is
    #  called. If there were any changes to the settings the user
    #  is asked if these should be saved (this does not happen for
    #  delete events).
    #
    #  2. for the 'add'-type button events the according new() dialog
    #  function is called; for delete events the according delete()
    #  function is called.
    def StorageEventHandler
      Builtins.y2milestone(
        "DriveEventHandler(): current event: '%1'",
        @currentEvent
      )
      if Ops.is_map?(@currentEvent)
        if :addDrive == Ops.get_symbol(@currentEvent, "WidgetID", :Empty)
          # 'Add Drive' button clicked
          Builtins.y2milestone("'Add Drive' button clicked")
          callDialogFunction(@currentDialog, :check)
          updateCurrentDialog("drive")
          callDialogFunction(@currentDialog, :new)
        elsif :addPart == Ops.get_symbol(@currentEvent, "WidgetID", :Empty)
          # 'Add Partition' button clicked
          Builtins.y2milestone("'Add Partition' button clicked")
          callDialogFunction(@currentDialog, :check)
          item = currentTreeItem
          if "" != item
            Ops.set(@stack, :which, stripTypePrefix(item))
          else
            Builtins.y2error("No item selected.")
          end
          updateCurrentDialog("part")
          callDialogFunction(@currentDialog, :new)
        elsif :addVG == Ops.get_symbol(@currentEvent, "WidgetID", :Empty)
          # 'Add Volume Group' button clicked
          Builtins.y2milestone("'Add Volume Group' button clicked")
          callDialogFunction(@currentDialog, :check)
          updateCurrentDialog("volgroup")
          callDialogFunction(@currentDialog, :new)
        elsif :delete == Ops.get_symbol(@currentEvent, "WidgetID", :Empty)
          # 'Delete' button clicked
          Builtins.y2milestone("'Delete' button clicked")
          item = currentTreeItem
          if "" != item
            Ops.set(@stack, :which, stripTypePrefix(item))
            callDialogFunction(
              updateCurrentDialog(getTypePrefix(item)),
              :delete
            )
            if 0 == AutoinstPartPlan.getDriveCount
              # if last drive was removed display new drive dialog
              updateCurrentDialog("drive")
              callDialogFunction(@currentDialog, :new)
            else
              # else display the now selected item
              item = currentTreeItem
              Ops.set(@stack, :which, stripTypePrefix(item))
              callDialogFunction(
                updateCurrentDialog(getTypePrefix(item)),
                :display
              )
            end
          else
            Builtins.y2milestone("No item selected.")
          end
        elsif :apply == Ops.get_symbol(@currentEvent, "WidgetID", :Empty)
          Builtins.y2milestone(
            "Apply button clicked in dialog '%1'. Storing settings.",
            @currentDialog
          )
          callDialogFunction(@currentDialog, :store)
          # reflect changes to AutoinstPartPlan in tree widget
          AutoinstPartPlan.updateTree
        end
      end

      nil
    end

    # TODO: this distinction between tree- and widget
    # events might be superflous and could be genralized.

    # Generic tree event dispatching
    def dispatchMenuEvent(_event)
      item = currentTreeItem
      if "" == item
        # User deselected current tree item. Happens when she clicks on empty line.
        Builtins.y2milestone(
          "Deselection event. Nothing happens, deliberately."
        )
      else
        # User selected a new tree item.

        # 1. check for changed settings in current dialog
        callDialogFunction(@currentDialog, :check)
        # 2. display new dialog
        Ops.set(@stack, :which, stripTypePrefix(item))
        callDialogFunction(updateCurrentDialog(getTypePrefix(item)), :display)
      end

      nil
    end

    # Generic widget event dispatching
    #
    # First, the dialog specific event handler gets a shot
    # afterwards the toplevel one kicks in.
    def dispatchWidgetEvent(event)
      event = deep_copy(event)
      eventHandler = Ops.get(@currentDialog, :eventHandler)
      @currentEvent = deep_copy(event)
      Builtins.eval(eventHandler)
      if Builtins.size(@currentEvent) != 0
        # the subdialog event handler didn't process the event, so
        # we call the toplevel handler
        StorageEventHandler()
      end

      nil
    end

    # Main Partitioning Dialog
    # @return [Symbol]
    def StorageDialog
      contents = HBox(
        HWeight(
          33,
          VBox(
            Tree(Id(:tree), Opt(:notify), _("Partition p&lan"), []),
            VSpacing(0.3),
            VBox(
              HBox(
                HSpacing(1),
                HWeight(50, PushButton(Id(:addDrive), _("Add D&rive"))),
                HWeight(50, PushButton(Id(:addPart), _("Add &Partition"))),
                HSpacing(1)
              ),
              HBox(
                HSpacing(1),
                HWeight(50, PushButton(Id(:addVG), _("Add &Volume Group"))),
                HWeight(50, PushButton(Id(:delete), _("&Delete"))),
                HSpacing(1)
              )
            ),
            VSpacing(1)
          )
        ),
        HSpacing(1),
        HWeight(
          66,
          VBox(
            VSpacing(1),
            Frame("", Top(ReplacePoint(Id(@replacement_point), EmptyDialog()))),
            VSpacing(1),
            HBox(
              Left(PushButton(Id(:back), Label.BackButton)),
              HStretch(),
              Right(PushButton(Id(:next), Label.FinishButton))
            )
          )
        ),
        HSpacing(1)
      )

      UI.OpenDialog(Opt(:defaultsize), contents)
      AutoinstPartPlan.updateTree

      # if there is no drive in partition plan, the user surely
      # wants to create one
      updateCurrentDialog("drive")
      if 0 == AutoinstPartPlan.getDriveCount
        callDialogFunction(@currentDialog, :new)
      else
        item = currentTreeItem
        Ops.set(@stack, :which, stripTypePrefix(item))
        callDialogFunction(@currentDialog, :display)
      end

      loop do
        event = UI.WaitForEvent
        item = currentTreeItem

        Builtins.y2milestone("Got event: '%1'", event)
        Builtins.y2milestone("Selected tree item: '%1'", item)

        # MAIN EVENT HANDLING
        #
        # General Event Handling Idea:
        #
        # There is a global map "dialogs" that maps dialog types to a
        # dialog map, which in turn stores call backs for stuff like
        # displaying the dialog contents, eventhandling, getting and setting
        # of settings,...
        #
        # This architecture avoids long if-elseif-cascades.
        event_id = :Empty
        event_id = Ops.get_symbol(event, "ID", :Empty) if Ops.is_symbol?(Ops.get(event, "ID"))
        if event_id == :abort || event_id == :back || event_id == :cancel
          return event_id
        elsif event_id == :next || event_id == :finish
          callDialogFunction(@currentDialog, :check)
          if AutoinstPartPlan.checkSanity
            # Only return successfully if plan is sane
            return event_id
          end
        elsif Ops.get_string(event, "EventType", "") == "MenuEvent" ||
            Ops.get_symbol(
              # ncurses sends following kind of event:
              event,
              "WidgetID",
              :Empty
            ) == @sTree
          # Tree Event
          dispatchMenuEvent(event)
        elsif Ops.get_string(event, "EventType", "") == "WidgetEvent"
          # Button was pressed
          dispatchWidgetEvent(event)
        end
      end
      :Empty
    end
  end
end
