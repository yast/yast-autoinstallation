# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

Yast.import "HTML"
Yast.import "RichText"

module Y2Autoinstallation
  # This class converts a list of issues into a message to be shown to users
  #
  # The message will summarize the list of issues, separating them into non-fatal
  # and fatal issues.
  class StorageProposalIssuesPresenter
    include Yast::I18n

    # @return [Y2Storage::AutoinstIssues::List] List of issues
    attr_reader :issues_list

    # Constructor
    #
    # @param issues_list [Y2Storage::AutoinstIssues::List] List of issues
    def initialize(issues_list)
      textdomain "autoinst"
      @issues_list = issues_list
    end

    # Return the text to be shown to the user regarding the list of issues
    #
    # @return [String] Plain text
    def to_plain
      Yast::RichText.Rich2Plain(to_html)
    end

    # Return the text to be shown to the user regarding the list of issues
    #
    # @return [String] HTML formatted text
    def to_html
      fatal, non_fatal = issues_list.partition(&:fatal?)

      parts = []
      parts << error_text(fatal) unless fatal.empty?
      parts << warning_text(non_fatal) unless non_fatal.empty?

      parts <<
      if fatal.empty?
        _("Do you want to continue?")
      else
        _("Please, correct these problems and try again.")
      end

      parts.join
    end

    # Return warning message with a list of issues
    #
    # @param issues [Array<Y2Storage::AutoinstIssues::Issue>] Array containing issues
    # @return [String] Message
    def warning_text(issues)
      Yast::HTML.Para(
        _("Some minor problems were detected while creating the partitioning plan:")
      ) + issues_list_text(issues)
    end

    # Return error message with a list of issues
    #
    # @param issues [Array<Y2Storage::AutoinstIssues::Issue>] Array containing issues
    # @return [String] Message
    def error_text(issues)
      Yast::HTML.Para(
        _("Some important problems were detected while creating the partitioning plan:")
      ) + issues_list_text(issues)
    end

    # Return an HTML representation for a list of issues
    def issues_list_text(issues)
      Yast::HTML.List(issues.map(&:message))
    end
  end
end
