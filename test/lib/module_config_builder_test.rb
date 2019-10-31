#!/usr/bin/env rspec

require_relative "../test_helper"
require_relative "../../src/lib/autoinstall/module_config_builder"

require "yast"

Yast.import "Y2ModuleConfig"

describe Yast::ModuleConfigBuilder do

  describe "#build" do
    let(:profile) do
      {
        "users"         => [{ "username" => "root", "uid" => 0 }, { "username" => "test", "uid" => 1000 }],
        "user_defaults" => { "group" => "1000" }
      }
    end

    let(:modspec) do
      {
        "res"  => "users",
        "data" => {
          "Name"                           => "User and Group Management",
          "GenericName"                    => "Add, Edit, Delete Users or User Groups",
          "Icon"                           => "yast-users",
          "X-SuSE-YaST-AutoInst"           => "all",
          "X-SuSE-YaST-Group"              => "Security",
          "X-SuSE-YaST-AutoInstMerge"      => "users,groups,user_defaults,login_settings",
          "X-SuSE-YaST-AutoInstMergeTypes" => "list,list,map,map",
          "X-SuSE-YaST-AutoInstClonable"   => "true",
          "X-SuSE-YaST-AutoInstRequires"   => "security",
          "X-SuSE-DocTeamID"               => "ycc_users",
          "X-SuSE-YaST-AutoInstClient"     => "users_auto"
        }
      }
    end

    it "returns a profile with the sections defined in X-SuSE-YaST-AutoInstMerge" do
      result = subject.build(modspec, profile)
      expect(result["users"]).to eq(profile["users"])
      expect(result["user_defaults"]).to eq(profile["user_defaults"])
    end

    context "when some section is not defined" do
      it "replaces that section with its default value (map or list)" do
        result = subject.build(modspec, profile)
        expect(result["groups"]).to eq([])
        expect(result["login_settings"]).to eq({})
      end
    end

    context "when base section is not defined" do
      let(:profile) { {} }

      it "returns false" do
        expect(subject.build(modspec, profile)).to eq(false)
      end
    end
  end
end
