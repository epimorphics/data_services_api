# frozen_string_literal: true

require './test/minitest_helper'

describe 'DataServicesAPI', 'the data services API' do
  it 'should have a semantic version' do
    _(DataServicesApi::VERSION).must_match(/\d+\.\d+\.\d+/)
  end

  it 'should be constructable with a given URL' do
    mock_notifier = MockNotifications.new

    dsapi = DataServicesApi::Service.new(url: 'foo/bar', instrumenter: mock_notifier)

    _(dsapi.url).must_match(%r{foo/bar})
  end
end
