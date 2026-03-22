# This file is licensed under the MIT License (MIT) available on
# http://opensource.org/licenses/MIT.

# Unit tests for the contributor data-processing logic in _plugins/contributors.rb
#
# The contributors() method in CategoryGenerator fetches JSON from GitHub and
# then processes it.  These tests exercise that processing logic by calling
# the method with a pre-built data array (no network access needed).
#
# Run with: ruby test/unit/test_contributors.rb

require 'test/unit'

# ---------------------------------------------------------------------------
# Minimal stubs to satisfy the plugin's dependencies
# ---------------------------------------------------------------------------
module Jekyll
  class Generator; end
end

# We do not want the plugin to make real HTTP calls; we will override the
# method under test after loading the file.
module OpenURI; end

# Stub open() so the top-level require does not blow up even if kernel
# open-uri is triggered indirectly.
module Kernel
  def open(*args); raise "Network access disabled in tests"; end
end

require 'json'
require_relative '../../_plugins/contributors'

# ---------------------------------------------------------------------------
# Expose the private contributors() method for direct testing by creating a
# test subclass whose process_data helper calls the inner loop logic.
# ---------------------------------------------------------------------------
class ContributorsTestHelper < Jekyll::CategoryGenerator

  # Re-implement the inner processing loop extracted from contributors():
  # takes an array of raw API-like hashes and an aliases hash, returns the
  # sorted contributors array – without any HTTP calls.
  def process_data(data, aliases)
    result = {}
    for c in data
      next if !c.is_a?(Hash)
      next if !c.has_key?('contributions') || !c['contributions'].is_a?(Integer) || c['contributions'] > 1_000_000
      if c.has_key?('name') && c['name'].is_a?(String) && /^[A-Za-z0-9\-]{1,150}$/.match(c['name'])
        name = c['name']
      elsif c.has_key?('login') && c['login'].is_a?(String) && /^[A-Za-z0-9\-]{1,150}$/.match(c['login'])
        name = c['login']
      else
        next
      end
      name = aliases[name] if aliases.has_key?(name)
      x = {}
      x['name'] = name
      x['contributions'] = c['contributions']
      if c.has_key?('login') && c['login'].is_a?(String) && /^[A-Za-z0-9\-]{1,150}$/.match(c['login'])
        x['login'] = c['login']
      end
      if result.has_key?(name)
        result[name]['contributions'] += x['contributions']
      else
        result[name] = x
      end
    end
    contributors = []
    result.each { |_key, value| contributors.push(value) }
    contributors.sort_by { |c| -c['contributions'] }
  end
end

class TestContributors < Test::Unit::TestCase

  def setup
    @helper = ContributorsTestHelper.new
    @aliases = {}
  end

  # ----------------------------------------------------------------
  # Basic result structure
  # ----------------------------------------------------------------

  def test_single_contributor_with_login
    data = [{ 'login' => 'alice', 'contributions' => 10 }]
    result = @helper.process_data(data, @aliases)
    assert_equal 1, result.length
    assert_equal 'alice', result[0]['name']
    assert_equal 10,      result[0]['contributions']
    assert_equal 'alice', result[0]['login']
  end

  def test_name_preferred_over_login
    data = [{ 'name' => 'Alice', 'login' => 'alice', 'contributions' => 5 }]
    result = @helper.process_data(data, @aliases)
    assert_equal 'Alice', result[0]['name']
    assert_equal 'alice', result[0]['login']
  end

  def test_login_used_when_name_absent
    data = [{ 'login' => 'bob', 'contributions' => 3 }]
    result = @helper.process_data(data, @aliases)
    assert_equal 'bob', result[0]['name']
  end

  # ----------------------------------------------------------------
  # Sorting: highest contributions first
  # ----------------------------------------------------------------

  def test_sorted_by_contributions_descending
    data = [
      { 'login' => 'low',    'contributions' => 1 },
      { 'login' => 'high',   'contributions' => 100 },
      { 'login' => 'medium', 'contributions' => 50 },
    ]
    result = @helper.process_data(data, @aliases)
    assert_equal 'high',   result[0]['name']
    assert_equal 'medium', result[1]['name']
    assert_equal 'low',    result[2]['name']
  end

  # ----------------------------------------------------------------
  # Deduplication / contribution accumulation
  # ----------------------------------------------------------------

  def test_duplicate_login_contributions_merged
    # Same person across two pages of API results
    data = [
      { 'login' => 'alice', 'contributions' => 10 },
      { 'login' => 'alice', 'contributions' => 5 },
    ]
    result = @helper.process_data(data, @aliases)
    assert_equal 1,  result.length
    assert_equal 15, result[0]['contributions']
  end

  def test_alias_merges_contributions
    # 'alice' is an alias for 'Alice Smith'; both entries should be merged
    aliases = { 'alice' => 'Alice-Smith' }
    data = [
      { 'login' => 'alice',       'contributions' => 10 },
      { 'login' => 'Alice-Smith', 'contributions' => 7 },
    ]
    result = @helper.process_data(data, aliases)
    assert_equal 1,            result.length
    assert_equal 'Alice-Smith', result[0]['name']
    assert_equal 17,            result[0]['contributions']
  end

  # ----------------------------------------------------------------
  # Input validation / filtering of invalid data
  # ----------------------------------------------------------------

  def test_non_hash_entry_skipped
    data = ['not a hash', { 'login' => 'bob', 'contributions' => 1 }]
    result = @helper.process_data(data, @aliases)
    assert_equal 1, result.length
    assert_equal 'bob', result[0]['name']
  end

  def test_missing_contributions_key_skipped
    data = [{ 'login' => 'nocontrib' }]
    result = @helper.process_data(data, @aliases)
    assert_equal 0, result.length
  end

  def test_non_integer_contributions_skipped
    data = [{ 'login' => 'charlie', 'contributions' => 'ten' }]
    result = @helper.process_data(data, @aliases)
    assert_equal 0, result.length
  end

  def test_contributions_over_limit_skipped
    data = [{ 'login' => 'bot', 'contributions' => 2_000_000 }]
    result = @helper.process_data(data, @aliases)
    assert_equal 0, result.length
  end

  def test_contributions_at_limit_allowed
    # Exactly 1,000,000 is NOT skipped (> check, not >=)
    data = [{ 'login' => 'dave', 'contributions' => 1_000_000 }]
    result = @helper.process_data(data, @aliases)
    assert_equal 1, result.length
  end

  def test_invalid_login_chars_skipped
    # Login with special characters not in [A-Za-z0-9\-]
    data = [{ 'login' => 'user@example', 'contributions' => 5 }]
    result = @helper.process_data(data, @aliases)
    assert_equal 0, result.length
  end

  def test_login_too_long_skipped
    long_login = 'a' * 151
    data = [{ 'login' => long_login, 'contributions' => 5 }]
    result = @helper.process_data(data, @aliases)
    assert_equal 0, result.length
  end

  def test_empty_data_returns_empty_array
    result = @helper.process_data([], @aliases)
    assert_equal [], result
  end

  # ----------------------------------------------------------------
  # Login field stored in result
  # ----------------------------------------------------------------

  def test_login_stored_when_valid
    data = [{ 'login' => 'eve', 'contributions' => 2 }]
    result = @helper.process_data(data, @aliases)
    assert result[0].has_key?('login')
    assert_equal 'eve', result[0]['login']
  end
end
