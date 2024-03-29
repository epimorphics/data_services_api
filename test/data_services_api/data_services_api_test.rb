# frozen_string_literal: true

require './test/minitest_helper'

describe 'DataServicesAPI', 'the data services API' do
  it 'should have a semantic version' do
    _(DataServicesApi::VERSION).must_match(/\d+\.\d+\.\d+/)
  end

  it 'should be constructable with a given URL' do
    instrumenter = MockNotifications.new
    mock_logger = mock('logger')
    mock_logger.expects(:info).at_least(0)

    dsapi = DataServicesApi::Service.new(url: 'foo/bar', instrumenter: instrumenter, logger: mock_logger)

    _(dsapi.url).must_match(%r{foo/bar})
  end
end
