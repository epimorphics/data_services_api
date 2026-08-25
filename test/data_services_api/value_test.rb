# frozen_string_literal: true

require './test/minitest_helper'

describe 'DataServicesApi::Value' do
  let(:v) { DataServicesApi::Value.new }

  it 'should initialize with no keys' do
    _(v.empty?).must_equal true
  end

  it 'should be immutable once created' do
    _(lambda {
      v[:foo] = 'bar'
    }).must_raise RuntimeError
  end

  it 'should specify a URI' do
    v1 = v.with_uri('http://foo/bar')

    _(v1.size).must_equal 1
    _(v1['@id']).must_equal 'http://foo/bar'
    _(v1.uri).must_equal 'http://foo/bar'
  end

  it 'should have a factory shortcut for creating a URI value' do
    v = DataServicesApi::Value.uri('http://fubar.com')

    _(v.size).must_equal 1
    _(v['@id']).must_equal 'http://fubar.com'
  end

  it 'should specify type and value' do
    v1 = v.with_typed_value('foo', 'http://fakexsd.org/bar')

    _(v1.size).must_equal 2

    _(v1['@value']).must_equal 'foo'
    _(v1.value).must_equal 'foo'

    _(v1['@type']).must_equal 'http://fakexsd.org/bar'
    _(v1.type).must_equal 'http://fakexsd.org/bar'
  end

  it 'should normalize symbol keys to strings' do
    v1 = DataServicesApi::Value.new('@id': 'http://foo/bar')

    _(v1['@id']).must_equal 'http://foo/bar'
    _(v1.uri).must_equal 'http://foo/bar'
    _(v1.key?(:@id)).must_equal false
  end

  it 'should specify a year and month value' do
    v1 = v.with_year_month(2016, 2)

    _(v1.type).must_equal 'http://www.w3.org/2001/XMLSchema#gYearMonth'
    _(v1.value).must_equal '2016-02'
  end
end
