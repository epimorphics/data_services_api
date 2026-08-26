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
    v1 = DataServicesApi::Value.uri('http://fubar.com')

    _(v1.size).must_equal 1
    _(v1['@id']).must_equal 'http://fubar.com'
  end

  it 'should specify type and value' do
    v1 = v.with_typed_value('foo', 'http://fakexsd.org/bar')

    _(v1.size).must_equal 2

    _(v1['@value']).must_equal 'foo'
    _(v1.value).must_equal 'foo'

    _(v1['@type']).must_equal 'http://fakexsd.org/bar'
    _(v1.type).must_equal 'http://fakexsd.org/bar'
  end

  it 'should specify a year and month value' do
    v1 = v.with_year_month(2016, 2)

    _(v1.type).must_equal 'http://www.w3.org/2001/XMLSchema#gYearMonth'
    _(v1.value).must_equal '2016-02'
  end

  describe 'key normalization' do
    it 'should normalize symbol keys to strings on construction' do
      v1 = DataServicesApi::Value.new('@id': 'http://foo/bar')

      _(v1['@id']).must_equal 'http://foo/bar'
      _(v1.key?(:@id)).must_equal false
    end

    it 'should read String and Symbol keys interchangeably via []' do
      v1 = v.with_uri('http://foo/bar')

      _(v1['@id']).must_equal 'http://foo/bar'
      _(v1[:@id]).must_equal 'http://foo/bar'
    end
  end

  describe '.from_json_ld' do
    it 'should read a string-keyed JSON-LD value node' do
      v1 = DataServicesApi::Value.from_json_ld('@value' => 'foo', '@type' => 'http://fakexsd.org/bar')

      _(v1.value).must_equal 'foo'
      _(v1.type).must_equal 'http://fakexsd.org/bar'
    end

    it 'should read a symbol-keyed JSON-LD value node' do
      v1 = DataServicesApi::Value.from_json_ld('@value': 'foo', '@type': 'http://fakexsd.org/bar')

      _(v1.value).must_equal 'foo'
      _(v1.type).must_equal 'http://fakexsd.org/bar'
    end

    it 'should read a URI reference node' do
      v1 = DataServicesApi::Value.from_json_ld('@id' => 'http://foo/bar')

      _(v1.uri).must_equal 'http://foo/bar'
    end
  end

  describe '#to_json' do
    it 'should serialize a URI value to the correct JSON-LD shape' do
      _(DataServicesApi::Value.uri('http://foo/bar').to_json).must_equal '{"@id":"http://foo/bar"}'
    end

    it 'should serialize a typed value to the correct JSON-LD shape' do
      v1 = DataServicesApi::Value.new.with_typed_value('foo', 'http://fakexsd.org/bar')

      _(v1.to_json).must_equal '{"@value":"foo","@type":"http://fakexsd.org/bar"}'
    end

    it 'should serialize correctly when embedded inside another structure' do
      terms = { 'ukhpi:refRegion' => { '@eq' => DataServicesApi::Value.uri('http://foo/bar') } }

      _(terms.to_json).must_equal '{"ukhpi:refRegion":{"@eq":{"@id":"http://foo/bar"}}}'
    end
  end
end
