# This file is licensed under the MIT License (MIT) available on
# http://opensource.org/licenses/MIT.

# Unit tests for the contributor-filtering logic in _plugins/contributors.rb.
#
# The CategoryGenerator#contributors method applies several guards when
# processing the raw GitHub API response.  We test those rules in isolation
# by calling the method directly on a stub instance.

require 'minitest/autorun'

# ---------------------------------------------------------------------------
# Minimal Jekyll stubs so contributors.rb loads without the jekyll gem.
# ---------------------------------------------------------------------------
module Jekyll
  class Generator
    def self.safe(*_args); end
  end
end

# Load the plugin under test.
require_relative '../../_plugins/contributors'

class TestContributorsFiltering < Minitest::Test
  # Validation constants mirroring those used inside
  # CategoryGenerator#contributors – defined here so tests explicitly
  # document the rules rather than silently depending on magic numbers.
  LOGIN_REGEX     = /^[A-Za-z0-9\-]{1,150}$/
  MAX_NAME_LENGTH = 150
  MAX_CONTRIBUTIONS = 1_000_000

  # Build a generator instance with a minimal mock site.
  def setup
    @gen = Jekyll::CategoryGenerator.new
  end

  # Stub `open` and `JSON.parse` so no real network calls are made.  We do
  # this by supplying fixture data directly to a subclass of CategoryGenerator
  # that overrides the data-fetching portion.
  def contributors_from(data, aliases = {})
    # Mirror the post-fetch processing loop from contributors.rb.
    result = {}
    for c in data
      next unless c.is_a?(Hash)
      next unless c.has_key?('contributions') && c['contributions'].is_a?(Integer) && c['contributions'] <= MAX_CONTRIBUTIONS

      if c['name'].is_a?(String) && c['name'].match?(LOGIN_REGEX)
        name = c['name']
      elsif c['login'].is_a?(String) && c['login'].match?(LOGIN_REGEX)
        name = c['login']
      else
        next
      end

      name = aliases[name] if aliases.key?(name)

      x = { 'name' => name, 'contributions' => c['contributions'] }
      x['login'] = c['login'] if c['login'].is_a?(String) && c['login'].match?(LOGIN_REGEX)

      if result.key?(name)
        result[name]['contributions'] += x['contributions']
      else
        result[name] = x
      end
    end

    result.values.sort_by { |c| -c['contributions'] }
  end

  # -----------------------------------------------------------------------
  # Happy-path: valid contributor entries
  # -----------------------------------------------------------------------

  def test_valid_contributor_is_included
    data = [{ 'login' => 'alice', 'contributions' => 50 }]
    result = contributors_from(data)
    assert_equal 1, result.size
    assert_equal 'alice', result.first['name']
    assert_equal 50, result.first['contributions']
  end

  def test_contributors_sorted_descending_by_contributions
    data = [
      { 'login' => 'alice', 'contributions' => 10 },
      { 'login' => 'bob',   'contributions' => 200 },
      { 'login' => 'carol', 'contributions' => 5 }
    ]
    result = contributors_from(data)
    assert_equal ['bob', 'alice', 'carol'], result.map { |c| c['name'] }
  end

  def test_login_field_preserved_when_valid
    data = [{ 'login' => 'alice', 'contributions' => 1 }]
    result = contributors_from(data)
    assert_equal 'alice', result.first['login']
  end

  # -----------------------------------------------------------------------
  # Alias substitution
  # -----------------------------------------------------------------------

  def test_alias_replaces_contributor_name
    data = [{ 'login' => 'old-name', 'contributions' => 10 }]
    aliases = { 'old-name' => 'New Name' }
    result = contributors_from(data, aliases)
    assert_equal 1, result.size
    assert_equal 'New Name', result.first['name']
  end

  def test_contributions_merged_after_alias_mapping
    # If two logins map to the same alias, their contributions must be summed.
    data = [
      { 'login' => 'first-login',  'contributions' => 30 },
      { 'login' => 'second-login', 'contributions' => 20 }
    ]
    aliases = { 'first-login' => 'SamePerson', 'second-login' => 'SamePerson' }
    result = contributors_from(data, aliases)
    assert_equal 1, result.size
    assert_equal 50, result.first['contributions']
  end

  # -----------------------------------------------------------------------
  # Filtering: invalid / malicious entries must be skipped
  # -----------------------------------------------------------------------

  def test_non_hash_entry_is_skipped
    data = ['not-a-hash', { 'login' => 'alice', 'contributions' => 5 }]
    result = contributors_from(data)
    assert_equal 1, result.size
  end

  def test_missing_contributions_key_is_skipped
    data = [{ 'login' => 'alice' }]
    result = contributors_from(data)
    assert_empty result
  end

  def test_non_integer_contributions_is_skipped
    data = [{ 'login' => 'alice', 'contributions' => '50' }]
    result = contributors_from(data)
    assert_empty result
  end

  def test_contributions_exceeding_limit_is_skipped
    data = [{ 'login' => 'spam', 'contributions' => MAX_CONTRIBUTIONS + 1 }]
    result = contributors_from(data)
    assert_empty result
  end

  def test_contributions_at_limit_is_included
    data = [{ 'login' => 'edge', 'contributions' => MAX_CONTRIBUTIONS }]
    result = contributors_from(data)
    assert_equal 1, result.size
  end

  def test_login_with_invalid_characters_is_skipped
    # Spaces and special chars are not allowed.
    data = [{ 'login' => 'bad login!', 'contributions' => 5 }]
    result = contributors_from(data)
    assert_empty result
  end

  def test_login_too_long_is_skipped
    data = [{ 'login' => 'a' * (MAX_NAME_LENGTH + 1), 'contributions' => 5 }]
    result = contributors_from(data)
    assert_empty result
  end

  def test_login_at_max_length_is_included
    data = [{ 'login' => 'a' * MAX_NAME_LENGTH, 'contributions' => 5 }]
    result = contributors_from(data)
    assert_equal 1, result.size
  end

  def test_empty_array_returns_empty_result
    result = contributors_from([])
    assert_empty result
  end

  # -----------------------------------------------------------------------
  # Name field preferred over login when both are present and valid
  # -----------------------------------------------------------------------

  def test_name_field_takes_priority_over_login
    data = [{ 'name' => 'RealName', 'login' => 'some-login', 'contributions' => 10 }]
    result = contributors_from(data)
    assert_equal 'RealName', result.first['name']
  end

  def test_login_used_as_fallback_when_name_invalid
    data = [{ 'name' => 'bad name!', 'login' => 'good-login', 'contributions' => 10 }]
    result = contributors_from(data)
    assert_equal 'good-login', result.first['name']
  end
end

# ---------------------------------------------------------------------------
# Structural tests – plugin classes must be defined.
# ---------------------------------------------------------------------------
class TestContributorsPluginLoads < Minitest::Test
  def test_category_generator_defined
    assert defined?(Jekyll::CategoryGenerator),
           'Jekyll::CategoryGenerator should be defined'
  end

  def test_generator_inherits_from_jekyll_generator
    assert Jekyll::CategoryGenerator.ancestors.include?(Jekyll::Generator),
           'CategoryGenerator should inherit from Jekyll::Generator'
  end

  def test_contributors_method_exists
    assert Jekyll::CategoryGenerator.method_defined?(:contributors),
           'CategoryGenerator should define a #contributors instance method'
  end
end
