# encoding: utf-8

# File:  include/tree.ycp
# Package:  Auto-installation/Partition
# Summary:     helper functions for dealing with tree widget
# Author:  Sven Schober (sschober@suse.de)
#
# $Id: tree.ycp 2805 2008-05-27 15:12:42Z sschober $
module Yast
  module AutoinstallTreeInclude
    def initialize_autoinstall_tree(include_target)
      Yast.import "UI"
      Yast.include include_target, "autoinstall/common.rb"

      # name of tree widget to be displayed (in storage dialog)
      @sTree = :tree
      # common way to refer to the tree widget id
      @iTree = Id(@sTree)
    end

    # Set tree widget to tree represented by newTree
    #
    # @param [Array<Yast::Term>] newTree tree to display.
    def setTree(newTree)
      newTree = deep_copy(newTree)
      UI.ChangeWidget(@iTree, :Items, newTree)

      nil
    end

    # Get the currently selected tree item id string.
    #
    # @return Item id string that is currently selected.
    def currentTreeItem
      symbol2string(Convert.to_symbol(UI.QueryWidget(@iTree, :Value)))
    end

    # Searches through term t recursively looking for an arg of
    # type string which is equal to s. This function is neccessary
    # due to the nature trees are stored/represented in the tree
    # widget.
    #
    # @param [Yast::Term] t The term to inspect.
    # @param [Symbol] s The symbol to look for.
    def termContains(t, s)
      t = deep_copy(t)
      # if term itself is named like s -> yes, contains
      return true if s == Builtins.symbolof(t)

      # other wise inspect arguments
      args = Builtins.argsof(t)
      found = false
      Builtins.foreach(args) do |e|
        if Ops.is_term?(e)
          found = termContains(Convert.to_term(e), s)
          raise Break if found
        elsif Ops.is(e, "list <term>")
          found = isContainedInTree(
            s,
            Convert.convert(e, from: "any", to: "list <term>")
          )
          raise Break if found
        elsif Ops.is_symbol?(e) && s == Convert.to_symbol(e)
          found = true
          raise Break
        end
      end
      found
    end

    def isContainedInTree(s, tree)
      tree = deep_copy(tree)
      found = false
      Builtins.foreach(tree) do |item|
        if termContains(item, s)
          found = true
          raise Break
        end
      end
      found
    end

    # Select item 'newItem' in tree.
    #
    # @return true if item exists in tree (and was selected), false
    # otherwise
    def selectTreeItem(newItem)
      item = string2symbol(newItem)
      allItems = Convert.convert(
        UI.QueryWidget(@iTree, :Items),
        from: "any",
        to:   "list <term>"
      )
      if isContainedInTree(item, allItems)
        UI.ChangeWidget(@iTree, :CurrentItem, item)
        return true
      end
      Builtins.y2warning("Item '%1' not found in tree", item)
      Builtins.y2debug("Tree was '%1'", allItems)
      false
    end

    # Wrapper function to create a new tree node
    #
    # @param [String] reference Tree item id string (e.g. "part_2_0")
    # @param [String] name Tree node name, displayed in widget
    # @param [Array<Yast::Term>] children list of child nodes
    def createTreeNode(reference, name, children)
      children = deep_copy(children)
      result = if 0 == Builtins.size(children)
        Item(Id(string2symbol(reference)), name)
      else
        Item(Id(string2symbol(reference)), name, true, children)
      end
      Builtins.y2milestone("new node: '%1'", result)
      deep_copy(result)
    end
  end
end
