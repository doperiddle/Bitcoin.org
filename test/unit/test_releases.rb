# This file is licensed under the MIT License (MIT) available on
# http://opensource.org/licenses/MIT.

# Unit tests for the versiontoint method in _plugins/releases.rb
# Run with: ruby test/unit/test_releases.rb

require 'test/unit'

# Minimal stubs so we can load the plugin without a full Jekyll environment
module Jekyll
  class Page
    def initialize; end
    def read_yaml(*args); end
    def process(*args); end
    def data; @data ||= {}; end
  end

  class Generator; end
end

# Load the plugin under test
require_relative '../../_plugins/releases'

class TestVersionToInt < Test::Unit::TestCase

  # Allocate an instance of ReleasePage without calling initialize
  # so we can invoke the pure versiontoint helper directly
  def setup
    @page = Jekyll::ReleasePage.allocate
  end

  # ----------------------------------------------------------------
  # Basic single-digit version strings
  # ----------------------------------------------------------------
  def test_single_digit_major
    assert_equal 1_000 ** 5, @page.versiontoint('1')
  end

  def test_zero_version
    assert_equal 0, @page.versiontoint('0')
  end

  # ----------------------------------------------------------------
  # Two-part version strings (major.minor)
  # ----------------------------------------------------------------
  def test_version_1_0
    expected = 1 * (1_000 ** 5)
    assert_equal expected, @page.versiontoint('1.0')
  end

  def test_version_0_1
    expected = 1 * (1_000 ** 4)
    assert_equal expected, @page.versiontoint('0.1')
  end

  def test_version_1_2
    expected = 1 * (1_000 ** 5) + 2 * (1_000 ** 4)
    assert_equal expected, @page.versiontoint('1.2')
  end

  # ----------------------------------------------------------------
  # Three-part version strings (major.minor.patch)
  # ----------------------------------------------------------------
  def test_version_0_11_0
    expected = 11 * (1_000 ** 4)
    assert_equal expected, @page.versiontoint('0.11.0')
  end

  def test_version_0_21_1
    expected = 21 * (1_000 ** 4) + 1 * (1_000 ** 3)
    assert_equal expected, @page.versiontoint('0.21.1')
  end

  def test_version_22_0_0
    expected = 22 * (1_000 ** 5)
    assert_equal expected, @page.versiontoint('22.0.0')
  end

  # ----------------------------------------------------------------
  # Four-part version strings
  # ----------------------------------------------------------------
  def test_version_0_13_2_0
    expected = 13 * (1_000 ** 4) + 2 * (1_000 ** 3)
    assert_equal expected, @page.versiontoint('0.13.2.0')
  end

  # ----------------------------------------------------------------
  # Ordering: a higher version must produce a larger integer
  # ----------------------------------------------------------------
  def test_ordering_major_beats_minor
    assert @page.versiontoint('1.0') > @page.versiontoint('0.99')
  end

  def test_ordering_minor_increment
    assert @page.versiontoint('0.12.0') > @page.versiontoint('0.11.9')
  end

  def test_ordering_patch_increment
    assert @page.versiontoint('0.21.1') > @page.versiontoint('0.21.0')
  end

  def test_ordering_same_version_equal
    assert_equal @page.versiontoint('0.21.0'), @page.versiontoint('0.21.0')
  end

  # ----------------------------------------------------------------
  # String input (version stored as a string in YAML)
  # ----------------------------------------------------------------
  def test_string_input
    # .to_s is called in the plugin before passing to versiontoint
    assert_equal @page.versiontoint('21.0'), @page.versiontoint(21.0.to_s)
  end
end
