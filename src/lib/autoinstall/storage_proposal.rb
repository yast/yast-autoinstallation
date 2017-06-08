require "y2storage"
require "y2storage/disk_analyzer"
require "y2storage/guided_proposal"
require "y2storage/auto_inst_proposal"

module Y2Autoinstallation
  # Storage proposal for AutoYaST
  #
  # This class it is mainly a wrapper around proposal Y2Storage proposal classes.
  # Depending on the profile, it will select the right class: if 'partitioning'
  # section is missing (or empty), {Y2Storage::GuidedProposal} will be used. Otherwise,
  # proposal will be handdled by {Y2Storage::AutoinstProposal}.
  class StorageProposal
    include Yast::Logger

    # @return [Y2Storage::Proposal] Y2Storage proposal instance
    attr_reader :proposal

    # Constructor
    #
    # @param partitioning [Array<Hash>] Partitioning section from the AutoYaST profile
    #
    # @see https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Partitioning
    def initialize(partitioning)
      @proposal = build_proposal(partitioning)
    end

    # Perform the proposal
    #
    # It delegates on the Y2Storage proposal instance
    def propose
      proposal.propose
    end

    # Propose and set the proposal on the StorageManager
    #
    # @return [Boolean] true if operation was successful; false otherwise
    def propose_and_store
      propose
      log.info "Storing successful proposal"
      Y2Storage::StorageManager.instance.proposal = proposal
      true
    rescue Y2Storage::Error => e
      log.warn "Proposal failed: #{e.inspect}"
      false
    end

  private

    # Initialize partition proposal
    #
    # @return [Boolean] true if proposal was successfully created; false otherwise.
    def build_proposal(partitioning)
      if partitioning.nil? || partitioning.empty?
        guided_proposal
      else
        auto_inst_proposal(partitioning)
      end
    end

    # Return an AutoInstProposal according to the AutoYaST profile
    #
    # @param partitioning [Array<Hash>] Partitioning specification from AutoYaST profile
    # @return [Y2Storage::AutoInstProposal]
    def auto_inst_proposal(partitioning)
      log.info "Initializing an autoinst proposal"
      Y2Storage::AutoInstProposal.new(
        partitioning:  partitioning,
        devicegraph:   devicegraph,
        disk_analyzer: disk_analyzer
      )
    end

    # Return a GuidedProposal according to product's proposal setting
    #
    # @return [Y2Storage::GuidedProposal]
    def guided_proposal
      log.info "Initializing a guided proposal"
      proposal_settings = Y2Storage::ProposalSettings.new_for_current_product
      Y2Storage::GuidedProposal.new(settings: proposal_settings)
    end

    # Return a DiskAnalyzer for the proposal's devicegraph
    #
    # @return [Y2Storage::DiskAnalyzer]
    def disk_analyzer
      @disk_analyzer ||= Y2Storage::DiskAnalyzer.new(devicegraph)
    end

    # Return the current devicegraph
    #
    # If no devicegraph was specified, the probed one will be used.
    #
    # @return [Y2Storage::Devicegraph]
    def devicegraph
      @devicegraph ||= Y2Storage::StorageManager.instance.y2storage_probed
    end
  end
end
