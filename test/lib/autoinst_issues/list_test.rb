#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require_relative '../../test_helper.rb'
require 'autoinstall/autoinst_issues/list'
require 'autoinstall/autoinst_issues/invalid_value'
require 'autoinstall/autoinst_issues/missing_value'

describe Y2Autoinstallation::AutoinstIssues::List do
  subject(:list) { described_class.new }

  describe '#add' do
    it 'adds a new issue to the list' do
      list.add(:missing_value, 'foo', 'bar')
      expect(list.to_a).to all(be_an(Y2Autoinstallation::AutoinstIssues::MissingValue))
    end

    it 'pass extra arguments to issue instance constructor' do
      expect(Y2Autoinstallation::AutoinstIssues::InvalidValue)
        .to receive(:new).with('firewall', 'interfaces', 'eth0',
                               _('This interface has been defined for more than one zone.'))
      list.add(:invalid_value, 'firewall', 'interfaces', 'eth0',
               _('This interface has been defined for more than one zone.'))
    end
  end

  describe '#to_a' do
    context 'when list is empty' do
      it 'returns an empty array' do
        expect(list.to_a).to eq([])
      end
    end

    context 'when some issue was added' do
      before do
        2.times { list.add(:missing_value, 'foo', 'bar') }
      end

      it 'returns an array containing added issues' do
        expect(list.to_a).to all(be_a(Y2Autoinstallation::AutoinstIssues::MissingValue))
        expect(list.to_a.size).to eq(2)
      end
    end
  end

  describe '#empty?' do
    context 'when list is empty' do
      it 'returns true' do
        expect(list).to be_empty
      end
    end

    context 'when some issue was added' do
      before { list.add(:missing_value, 'foo', 'bar') }

      it 'returns false' do
        expect(list).to_not be_empty
      end
    end
  end

  describe '#fatal?' do
    context 'when contains some fatal error' do
      before { list.add(:missing_value, 'foo', 'bar', 'descritption', :fatal) }

      it 'returns true' do
        expect(list).to be_fatal
      end
    end

    context 'when contains no fatal error' do
      before { list.add(:missing_value, 'foo', 'bar', 'descritption', :warn) }

      it 'returns false' do
        expect(list).to_not be_fatal
      end
    end
  end
end
