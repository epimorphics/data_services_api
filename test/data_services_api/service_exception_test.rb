# frozen_string_literal: true

require './test/minitest_helper'

describe 'DataServicesAPI::ServiceException' do
  it 'exposes the service message passed to it' do
    exception = DataServicesApi::ServiceException.new('boom', 404, 'http://example.com', 'not found')

    _(exception.message).must_equal 'boom'
    _(exception.status).must_equal 404
    _(exception.source).must_equal 'http://example.com'
    _(exception.service_message).must_equal 'not found'
  end
end
