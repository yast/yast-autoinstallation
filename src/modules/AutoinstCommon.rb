# encoding: utf-8

# File:  modules/AutoinstCommon.ycp
# Package:  Auto-installation/Partition
# Summary:  Common partitioning functions module
# Author:  Sven Schober (sschober@suse.de)
#
# $Id: AutoinstCommon.ycp 2788 2008-05-13 10:00:17Z sschober $
require "yast"

module Yast
  class AutoinstCommonClass < Module
    def main
      textdomain "autoinst"
    end

    def typeof(o)
      o = deep_copy(o)
      if Ops.is_integer?(o)
        return :integer
      elsif Ops.is_symbol?(o)
        return :symbol
      elsif Ops.is_string?(o)
        return :string
      elsif Ops.is_boolean?(o)
        return :boolean
      end

      nil
    end

    # Predicates
    def isValidField(objectDefinition, field)
      objectDefinition = deep_copy(objectDefinition)
      Ops.get(objectDefinition, field) != nil
    end

    def isValidObject(objectDefinition, obj)
      objectDefinition = deep_copy(objectDefinition)
      obj = deep_copy(obj)
      result = true
      Builtins.foreach(obj) do |field, _value|
        result = isValidField(objectDefinition, field)
      end
      result
    end

    def hasValidType(objectDefinition, field, value)
      objectDefinition = deep_copy(objectDefinition)
      value = deep_copy(value)
      if isValidField(objectDefinition, field)
        return typeof(Ops.get(objectDefinition, field)) == typeof(value)
      end

      # if field doesn't exit in the first place, all types are correct
      true
    end

    def areEqual(d1, d2)
      d1 = deep_copy(d1)
      d2 = deep_copy(d2)
      result = true
      Builtins.foreach(d1) do |key, value|
        otherValue = Ops.get(d2, key)
        if value != otherValue
          Builtins.y2milestone(
            "d1['%1']='%2' != d2['%1']='%3'",
            key,
            value,
            otherValue
          )
          result = false
        end
      end
      result
    end

    # Setter

    def set(objectDefinition, obj, field, value)
      objectDefinition = deep_copy(objectDefinition)
      obj = deep_copy(obj)
      value = deep_copy(value)
      if isValidObject(objectDefinition, obj)
        if isValidField(objectDefinition, field)
          if hasValidType(objectDefinition, field, value)
            return Builtins.add(obj, field, value)
          else
            Builtins.y2error(
              "Value '%1' ('%2') is not of correct type '%3'.",
              value,
              typeof(value),
              typeof(Ops.get(objectDefinition, field))
            )
          end
        else
          Builtins.y2error("Not a valid field: '%1'.", field)
        end
      else
        Builtins.y2error("No valid object: '%1'", obj)
      end
      deep_copy(obj)
    end

    publish function: :isValidField, type: "boolean (map <string, any>, string)"
    publish function: :isValidObject, type: "boolean (map <string, any>, map <string, any>)"
    publish function: :hasValidType, type: "boolean (map <string, any>, string, any)"
    publish function: :areEqual, type: "boolean (map <string, any>, map <string, any>)"
    publish function: :set, type: "map <string, any> (map <string, any>, map <string, any>, string, any)"
  end

  AutoinstCommon = AutoinstCommonClass.new
  AutoinstCommon.main
end
