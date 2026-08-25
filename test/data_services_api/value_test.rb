# frozen_string_literal: true

require './test/minitest_helper'

describe 'DataServicesApi::Value' do
  let(:v) { DataServicesApi::Value.new }

  it 'should initialize with no fields set' do
    _(v.value).must_be_nil
    _(v.type).must_be_nil
    _(v.uri).must_be_nil
  end

  it 'should be immutable once created' do
    _(v.frozen?).must_equal true
  end

  it 'should specify a URI' do
    v1 = v.with_uri('http://foo/bar')

    _(v1.uri).must_equal 'http://foo/bar'
  end

  it 'should have a factory shortcut for creating a URI value' do
    v1 = DataServicesApi::Value.uri('http://fubar.com')

    _(v1.uri).must_equal 'http://fubar.com'
  end

  it 'should specify type and value' do
    v1 = v.with_typed_value('foo', 'http://fakexsd.org/bar')

    _(v1.value).must_equal 'foo'
    _(v1.type).must_equal 'http://fakexsd.org/bar'
  end

  it 'should specify a year and month value' do
    v1 = v.with_year_month(2016, 2)

    _(v1.type).must_equal 'http://www.w3.org/2001/XMLSchema#gYearMonth'
    _(v1.value).must_equal '2016-02'
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

  describe '#==' do
    it 'should be equal to another Value with the same fields' do
      _(DataServicesApi::Value.uri('http://foo/bar')).must_equal DataServicesApi::Value.uri('http://foo/bar')
    end

    it 'should not be equal to a Value with different fields' do
      _(DataServicesApi::Value.uri('http://foo/bar')).wont_equal DataServicesApi::Value.uri('http://other')
    end

    it 'should not be equal to a plain Hash' do
      _(DataServicesApi::Value.uri('http://foo/bar')).wont_equal({ '@id' => 'http://foo/bar' })
    end
  end
end
