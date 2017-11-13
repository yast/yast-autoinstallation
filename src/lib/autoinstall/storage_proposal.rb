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

require "y2storage"

module Y2Autoinstallation
  # Storage proposal for AutoYaST
  #
  # This class it is mainly a wrapper around proposal Y2Storage proposal classes.
  # Depending on the profile, it will select the right class: if 'partitioning'
  # section is missing (or empty), {Y2Storage::GuidedProposal} will be used. Otherwise,
  # proposal will be handdled by {Y2Storage::AutoinstProposal}.
  class StorageProposal
    include Yast::Logger

    # @return [Y2Storage::GuidedProposal,Y2Storage::AutoinstProposal] Y2Storage proposal instance
    attr_reader :proposal

    # @return [Y2Storage::AutoinstIssues::List] Storage proposal issues list
    attr_reader :issues_list

    # Constructor
    #
    # @param partitioning [Array<Hash>] Partitioning section from the AutoYaST profile
    #
    # @see https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Partitioning
    def initialize(partitioning)
      @issues_list = Y2Storage::AutoinstIssues::List.new
      build_proposal(partitioning)
    end

    # Set the proposal on the StorageManager
    def save
      Y2Storage::StorageManager.instance.proposal = proposal
    end

    # A proposal is failed when it has not devices after being proposed
    # @see Y2Storage::Proposal::Base#failed?
    #
    # @return [Boolean] true if proposed and has no devices; false otherwise
    def failed?
      proposal.failed?
    end

    # Determine if any issue was found while creating the proposal
    #
    # @return [Boolean] true if some problem was found; false otherwise
    def issues?
      !issues_list.empty?
    end

    # Determine whether the proposal is valid for installation
    #
    # There a chance that the user forgets about specifying the root partition.
    # In such case, the proposal can succeed but it is not possible to install
    # a system on it.
    #
    # @return [Boolean] true if some problem was found; false otherwise
    def valid?
      !(failed? || issues?)
    end

  private

    # Initialize the partition proposal
    #
    # It will depend different proposals depending on {partitioning}:
    #
    # * {Y2Storage::GuidedProposal} if {partitioning} is nil or empty;
    # * {Y2Storage::AutoinstProposal} in any other case.
    #
    # @return [Y2Storage::GuidedProposal,Y2Storage::AutoinstProposal] Proposal instance
    def build_proposal(partitioning)
      if partitioning.nil? || partitioning.empty?
        @proposal = guided_proposal
      else
        @proposal = autoinst_proposal(partitioning)
        @proposal.propose
      end
    rescue Y2Storage::Error => e
      handle_exception(e)
    end

    # Return an AutoinstProposal according to the AutoYaST profile
    #
    # @note A proposal is returned even when it is a failed one
    #
    # @param partitioning [Array<Hash>] Partitioning specification from AutoYaST profile
    # @return [Y2Storage::AutoinstProposal]
    def autoinst_proposal(partitioning)
      log.info "Creating an autoinstall proposal"
      Y2Storage::AutoinstProposal.new(partitioning: partitioning, issues_list: issues_list)
    end

    # Return a GuidedProposal according to product's proposal setting
    #
    # Product's settings could be modified if there is no way to create a
    # proposal with those settings.
    #
    # @see Y2Storage::GuidedProposal.initial
    #
    # @return [Y2Storage::GuidedProposal]
    def guided_proposal
      log.info "Creating a guided proposal"
      Y2Storage::GuidedProposal.initial
    end

    # Handle Y2Storage exceptions
    #
    # Some of the exceptions can be handled as an AutoYaST problem in order to offer further
    # information to the user. For the rest of cases, the exception is catched and displayed
    # in a reasonable way (no translation, for instance).
    def handle_exception(error)
      log.warn "Autoinstall proposal failed: #{error.inspect}"
      case error
      when Y2Storage::NoDiskSpaceError
        issues_list.add(:no_disk_space)
      when Y2Storage::Error
        issues_list.add(:exception, error)
      else
        raise error
      end
    end

  end
end
