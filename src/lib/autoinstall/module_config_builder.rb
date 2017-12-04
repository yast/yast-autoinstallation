module Yast
  # Builds configuration for an AutoYaST module
  #
  # This class builds a module configuration according to its specification (in
  # a .desktop file) and an AutoYaST profile.
  #
  # @see #build
  class ModuleConfigBuilder
    MERGE_KEYS = "X-SuSE-YaST-AutoInstMerge"
    MERGE_TYPES = "X-SuSE-YaST-AutoInstMergeTypes"
    DEFAULT_TYPES = { "map" => {}, "list" => [] }

    # Builds a module configuration
    #
    # This is just a convenience method which relies on #build.
    #
    # @see #build
    def self.build(modspec, profile)
      new.build(modspec, profile)
    end

    # Builds a module configuration according to its specification and a profile
    #
    # It relies on X-SuSE-YaST-AutoInstMerge and X-SuSE-YaST-AutoInstMergeTypes
    # to merge configuration from related profile sections.
    #
    # @param [Hash] modspec Module specification (containin +res+ and +data+ keys).
    # @param [Hash] profile   AutoYaST profile to read documentation from.
    # @return [Hash] Module configuration.
    def build(modspec, profile)
      return false if profile[resource_name(modspec)].nil?
      types_map(modspec).each_with_object({}) do |section, hsh|
        key, type = section
        hsh[key] = profile[key] || default_value_for(type)
      end
    end

    # Returns the resource name from the module configuration
    #
    # It tries to find the name under the key
    # Yast::Y2ModuleConfigClass::RESOURCE_NAME_KEY. If it's not defined,
    # just take the default one.
    #
    # @param [Hash] modspec Module specification (containing +res+ and +data+ keys).
    # @return [String] Resource name
    def resource_name(modspec)
      resource = modspec["data"][Yast::Y2ModuleConfigClass::RESOURCE_NAME_KEY]
      if resource && !resource.empty?
        resource
      else
        modspec["res"]
      end
    end

    private

    # Builds a map containing keys to merge and its corresponding types.
    #
    # @param [Hash] modspec Module specification (containing +res+ and +data+ keys).
    # @return [Hash] Hash containing keys => types.
    #
    # @example
    #   types_map("res" => "users", "data" =>
    #     { MERGE_KEYS => "users,user_defaults", MERGE_TYPES => "map,list"})
    #   #=> { "users" => "map", "user_defaults" => "list" }
    def types_map(modspec)
      keys = modspec["data"][MERGE_KEYS].split(",").map(&:strip)
      types = modspec["data"][MERGE_TYPES].split(",").map(&:strip)
      Hash[keys.zip(types)]
    end

    # Returns the default value for a configuration parameter type.
    #
    # Default types are defined in DEFAULT_TYPES constant.
    #
    # @param type [String] Type name.
    # @return [Hash,Array] It returns the default value for the given type.
    def default_value_for(type)
      if DEFAULT_TYPES[type]
        DEFAULT_TYPES[type].clone
      else
        raise "Not default value defined for type #{type}"
      end
    end
  end
end
