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

    # Constructor
    #
    # @param partitioning [Array<Hash>] Partitioning section from the AutoYaST profile
    #
    # @see https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Partitioning
    def initialize(partitioning)
      @proposal = build_proposal(partitioning)
    end

    # Set the proposal on the StorageManager
    def save
      Y2Storage::StorageManager.instance.proposal = proposal
    end

    # A proposal is failed when it has not devices after being proposed
    # @see Y2Storage::Proposal::Base#failed?
    #
    # @return [Boolean] true if proposed and has not devices; false otherwise
    def failed?
      proposal.failed?
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
        guided_proposal
      else
        autoinst_proposal(partitioning)
      end
    end

    # Return an AutoinstProposal according to the AutoYaST profile
    #
    # @note A proposal is retured even when it is a failed one
    #
    # @param partitioning [Array<Hash>] Partitioning specification from AutoYaST profile
    # @return [Y2Storage::AutoinstProposal]
    def autoinst_proposal(partitioning)
      log.info "Creating an autoinstall proposal"
      proposal = Y2Storage::AutoinstProposal.new(partitioning:  partitioning)
      proposal.propose
      proposal
    rescue Y2Storage::Error => e
      log.warn "Autoinstall proposal failed: #{e.inspect}"
      proposal
    end

    # Return a GuidedProposal according to product's proposal setting
    #
    # Product's settings could be modified if there is no way to create a
    # proposal with that settings.
    #
    # @see Y2Storage::GuidedProposal.initial
    #
    # @return [Y2Storage::GuidedProposal]
    def guided_proposal
      log.info "Creating a guided proposal"
      Y2Storage::GuidedProposal.initial
    end
  end
end
