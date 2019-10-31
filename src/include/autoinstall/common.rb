# encoding: utf-8

# File:  include/common.ycp
# Package:  Auto-installation/Partition
# Summary:     common helper functions
# Author:  Sven Schober (sschober@suse.de)
#
# $Id: common.ycp 2805 2008-05-27 15:12:42Z sschober $
module Yast
  module AutoinstallCommonInclude
    def initialize_autoinstall_common(include_target)
      textdomain "autoinst"

      Yast.include include_target, "autoinstall/types.rb"

      Yast.import "AutoinstStorage"

      @currentDialog = {}
      # because i don't know how to pass arguments to eval()
      # i use this global map as a stack
      @stack = {}

      @currentEvent = {}
      @replacement_point = :rp

      # Global dialogs map. See StorageDialog() for more detailed
      # description of the general architecture.
      @dialogs = {}
    end

    def addDialog(name, dialog)
      dialog = deep_copy(dialog)
      @dialogs = Builtins.add(@dialogs, name, dialog)

      nil
    end

    def symbol2string(s)
      return "" if nil == s

      Builtins.substring(Builtins.tostring(s), 1)
    end

    def string2symbol(s)
      Builtins.symbolof(Builtins.toterm(s))
    end

    def toItemList(sList)
      sList = deep_copy(sList)
      Builtins.maplist(sList) { |s| Item(Id(string2symbol(s)), s) }
    end

    def updateCurrentDialog(dialogType)
      @currentDialog = Ops.get(@dialogs, dialogType, {})
      deep_copy(@currentDialog)
    end

    def getDialog(dialogType)
      Ops.get(@dialogs, dialogType, {})
    end

    def prepareStack
      # TODO: implement.
      Builtins.y2milestone("prepareStack(): NOT IMPLEMENTED")

      nil
    end

    def callDialogFunction(dialog, function)
      dialog = deep_copy(dialog)
      functionTerm = Ops.get(dialog, function)
      if nil != functionTerm
        Builtins.y2milestone(
          "calling function: '%1'->'%2'.",
          Ops.get_string(dialog, :type, "Unknown"),
          functionTerm
        )
        # prepareStack();
        Builtins.eval(functionTerm)
      else
        Builtins.y2milestone(
          "Function not found: '%1'->'%2'.",
          Ops.get_string(dialog, :type, "Unknown"),
          function
        )
      end

      nil
    end

    # Called by event handles to indicate the current event has been
    # handled
    def eventHandled
      @currentEvent = {}

      nil
    end

    # extracts type from tree item id strings:
    # "part_2_0" -> "part"
    def getTypePrefix(item)
      if nil != item && "" != item
        return Builtins.substring(item, 0, Builtins.findfirstof(item, "_"))
      end

      item
    end

    # strips off type prefixes from tree item id strings:
    # "part_2_0" -> "2_0"
    def stripTypePrefix(item)
      if nil != item && "" != item
        return Builtins.substring(
          item,
          Ops.add(Builtins.findfirstof(item, "_"), 1)
        )
      end
      item
    end

    # TODO: might be optimized by not using a regex here
    def removePrefix(s, prefix)
      result = Builtins.regexpsub(s, Ops.add(prefix, "(.*)"), "\\1")
      return s if nil == result

      result
    end

    # seems a bit over eager to supply this, but for consistencies
    # sake...
    def addPrefix(s, prefix)
      Ops.add(prefix, s)
    end
  end
end
