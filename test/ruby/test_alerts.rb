# This file is licensed under the MIT License (MIT) available on
# http://opensource.org/licenses/MIT.

# Unit tests for the date-validation logic in _plugins/alerts.rb.
#
# The AlertPageGenerator#generate method skips alert files whose names do
# not match a strict YYYY-MM-DD prefix pattern.  We extract and test those
# validation rules in isolation so regressions are caught without a full
# Jekyll build.

require 'minitest/autorun'
require 'yaml'

# ---------------------------------------------------------------------------
# Minimal Jekyll stubs so alerts.rb loads without the jekyll gem.
# ---------------------------------------------------------------------------
module Jekyll
  class Page
    attr_accessor :data, :dir, :name, :site, :base
    def initialize; @data = {}; end
    def process(name); @name = name; end
    def read_yaml(_dir, _file); @data = {}; end
  end

  class Generator
    def self.safe(*_args); end
  end
end

# Load the plugin under test.
require_relative '../../_plugins/alerts'

# ---------------------------------------------------------------------------
# Helper that mirrors the filename-validation logic inside
# AlertPageGenerator#generate exactly as written in alerts.rb:
#
#   date = dst.split('-')
#   next if date.length < 4
#   date = date[0] + '-' + date[1] + '-' + date[2]
#   next if !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.match(date)
# ---------------------------------------------------------------------------
module AlertDateValidator
  DATE_REGEX = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/

  # Returns true when the filename passes all guards in generate, i.e. the
  # file would NOT be skipped.
  def self.valid_alert_filename?(filename)
    parts = filename.split('-')
    return false if parts.length < 4

    date_str = [parts[0], parts[1], parts[2]].join('-')
    return false unless DATE_REGEX.match(date_str)

    true
  end
end

class TestAlertDateValidation < Minitest::Test
  # -----------------------------------------------------------------------
  # Valid filenames
  # -----------------------------------------------------------------------

  def test_typical_alert_filename_is_valid
    # The standard format is YYYY-MM-DD-slug.html
    assert AlertDateValidator.valid_alert_filename?('2020-01-15-some-alert.html'),
           '2020-01-15-some-alert.html should be valid'
  end

  def test_multi_word_slug_is_valid
    assert AlertDateValidator.valid_alert_filename?('2021-12-31-bitcoin-core-alert.html'),
           'Multi-word slug should be valid'
  end

  def test_minimum_valid_filename_four_parts
    # Exactly four dash-separated components: YYYY MM DD slug
    assert AlertDateValidator.valid_alert_filename?('2019-06-01-x'),
           'Four-part filename should be valid'
  end

  def test_date_with_leading_zeros_is_valid
    assert AlertDateValidator.valid_alert_filename?('2015-01-01-alert'),
           'Dates with leading zeros should be valid'
  end

  # -----------------------------------------------------------------------
  # Invalid filenames (would be skipped by generate)
  # -----------------------------------------------------------------------

  def test_too_few_parts_is_invalid
    # Only 3 dash-separated components – generator would skip it.
    refute AlertDateValidator.valid_alert_filename?('2020-01-alert.html'),
           '3-part filename should be invalid (less than 4 parts)'
  end

  def test_non_numeric_year_is_invalid
    refute AlertDateValidator.valid_alert_filename?('ABCD-01-15-slug.html'),
           'Non-numeric year should be invalid'
  end

  def test_non_numeric_month_is_invalid
    refute AlertDateValidator.valid_alert_filename?('2020-AB-15-slug.html'),
           'Non-numeric month should be invalid'
  end

  def test_non_numeric_day_is_invalid
    refute AlertDateValidator.valid_alert_filename?('2020-01-XY-slug.html'),
           'Non-numeric day should be invalid'
  end

  def test_two_digit_year_is_invalid
    # Year must be exactly 4 digits.
    refute AlertDateValidator.valid_alert_filename?('20-01-15-slug.html'),
           '2-digit year should be invalid'
  end

  def test_single_digit_month_is_invalid
    # Month must be exactly 2 digits.
    refute AlertDateValidator.valid_alert_filename?('2020-1-15-slug.html'),
           '1-digit month should be invalid'
  end

  def test_single_digit_day_is_invalid
    # Day must be exactly 2 digits.
    refute AlertDateValidator.valid_alert_filename?('2020-01-5-slug.html'),
           '1-digit day should be invalid'
  end

  # -----------------------------------------------------------------------
  # Edge-case strings
  # -----------------------------------------------------------------------

  def test_empty_string_is_invalid
    refute AlertDateValidator.valid_alert_filename?(''),
           'Empty string should be invalid'
  end

  def test_only_dashes_is_invalid
    refute AlertDateValidator.valid_alert_filename?('---'),
           'Only dashes should be invalid'
  end

  def test_five_parts_still_valid
    # Extra parts beyond the date prefix are fine.
    assert AlertDateValidator.valid_alert_filename?('2022-03-14-foo-bar-baz'),
           'Five-part filename with valid date prefix should be valid'
  end
end

# ---------------------------------------------------------------------------
# Tests that verify AlertPageGenerator exists and is discoverable by Jekyll.
# ---------------------------------------------------------------------------
class TestAlertsPluginLoads < Minitest::Test
  def test_alert_page_class_defined
    assert defined?(Jekyll::AlertPage), 'Jekyll::AlertPage should be defined'
  end

  def test_alert_page_generator_class_defined
    assert defined?(Jekyll::AlertPageGenerator),
           'Jekyll::AlertPageGenerator should be defined'
  end

  def test_generator_inherits_from_jekyll_generator
    assert Jekyll::AlertPageGenerator.ancestors.include?(Jekyll::Generator),
           'AlertPageGenerator should inherit from Jekyll::Generator'
  end
end
