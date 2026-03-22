# This file is licensed under the MIT License (MIT) available on
# http://opensource.org/licenses/MIT.

# Unit tests for the versiontoint helper defined in _plugins/releases.rb.
# We stub the Jekyll namespace so the plugin can be loaded without requiring
# the jekyll gem, then exercise ReleasePage#versiontoint via Object#allocate
# (which creates an instance without triggering the full initialize chain).

require 'minitest/autorun'
require 'yaml'

# ---------------------------------------------------------------------------
# Minimal Jekyll stubs – just enough for releases.rb to load cleanly.
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
require_relative '../../_plugins/releases'

class TestVersionToInt < Minitest::Test
  # Use allocate so we can call the pure helper without running initialize,
  # which would try to read files from disk and abort on missing YAML keys.
  def page
    Jekyll::ReleasePage.allocate
  end

  # -----------------------------------------------------------------------
  # Basic single-component versions
  # -----------------------------------------------------------------------

  def test_zero_version_returns_zero
    assert_equal 0, page.versiontoint('0')
  end

  def test_single_digit_version
    assert_equal 1 * (1000**5), page.versiontoint('1')
  end

  def test_single_digit_version_22
    assert_equal 22 * (1000**5), page.versiontoint('22')
  end

  # -----------------------------------------------------------------------
  # Two-component versions
  # -----------------------------------------------------------------------

  def test_two_part_version_zero_minor
    # "22.0" => 22*1000^5 + 0*1000^4
    expected = 22 * (1000**5) + 0 * (1000**4)
    assert_equal expected, page.versiontoint('22.0')
  end

  def test_two_part_version_nonzero_minor
    # "0.21" => 0*1000^5 + 21*1000^4
    expected = 0 * (1000**5) + 21 * (1000**4)
    assert_equal expected, page.versiontoint('0.21')
  end

  # -----------------------------------------------------------------------
  # Three-component versions (most common Bitcoin Core format)
  # -----------------------------------------------------------------------

  def test_three_part_version_0_21_1
    # "0.21.1" => 0*1000^5 + 21*1000^4 + 1*1000^3
    expected = 0 * (1000**5) + 21 * (1000**4) + 1 * (1000**3)
    assert_equal expected, page.versiontoint('0.21.1')
  end

  def test_three_part_version_0_20_0
    expected = 0 * (1000**5) + 20 * (1000**4) + 0 * (1000**3)
    assert_equal expected, page.versiontoint('0.20.0')
  end

  def test_three_part_version_0_20_1
    expected = 0 * (1000**5) + 20 * (1000**4) + 1 * (1000**3)
    assert_equal expected, page.versiontoint('0.20.1')
  end

  # -----------------------------------------------------------------------
  # Ordering – higher release strings must produce higher integers
  # -----------------------------------------------------------------------

  def test_ordering_major_wins
    assert page.versiontoint('22.0') > page.versiontoint('0.21.1'),
           '22.0 should be greater than 0.21.1'
  end

  def test_ordering_minor_wins_over_patch
    assert page.versiontoint('0.21.1') > page.versiontoint('0.21.0'),
           '0.21.1 should be greater than 0.21.0'
  end

  def test_ordering_minor_increment
    assert page.versiontoint('0.21.0') > page.versiontoint('0.20.0'),
           '0.21.0 should be greater than 0.20.0'
  end

  def test_ordering_1_beats_0_99_9
    # The integer representation should reflect semantic versioning intent.
    assert page.versiontoint('1.0') > page.versiontoint('0.99.9'),
           '1.0 should be greater than 0.99.9'
  end

  def test_ordering_multi_digit_major
    assert page.versiontoint('10.0') > page.versiontoint('9.0'),
           '10.0 should be greater than 9.0'
  end

  def test_ordering_multi_digit_minor
    assert page.versiontoint('0.100') > page.versiontoint('0.99'),
           '0.100 should be greater than 0.99'
  end

  # -----------------------------------------------------------------------
  # Idempotency / determinism
  # -----------------------------------------------------------------------

  def test_same_version_same_int
    v = '0.21.1'
    assert_equal page.versiontoint(v), page.versiontoint(v),
                 'versiontoint must be deterministic'
  end

  # -----------------------------------------------------------------------
  # Five-component version (maximum depth the formula supports)
  # -----------------------------------------------------------------------

  def test_five_part_version
    # Each component contributes 1000^(5-k) for index k.
    expected = 1*(1000**5) + 2*(1000**4) + 3*(1000**3) + 4*(1000**2) + 5*(1000**1)
    assert_equal expected, page.versiontoint('1.2.3.4.5')
  end
end
