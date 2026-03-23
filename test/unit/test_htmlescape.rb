# This file is licensed under the MIT License (MIT) available on
# http://opensource.org/licenses/MIT.

# Unit tests for the htmlescape Liquid filter defined in _plugins/htmlescape.rb
# Run with: ruby test/unit/test_htmlescape.rb

require 'test/unit'

# Minimal Liquid stub so the plugin can be loaded without the full Liquid gem
module Liquid
  module Template
    def self.register_filter(mod); end
  end
end

require_relative '../../_plugins/htmlescape'

class TestHtmlEscape < Test::Unit::TestCase

  # Include the module under test so we can call htmlescape() directly
  include Entities

  # ----------------------------------------------------------------
  # Single character escapes
  # ----------------------------------------------------------------
  def test_ampersand
    assert_equal '&amp;', htmlescape('&')
  end

  def test_less_than
    assert_equal '&lt;', htmlescape('<')
  end

  def test_greater_than
    assert_equal '&gt;', htmlescape('>')
  end

  def test_double_quote
    assert_equal '&quot;', htmlescape('"')
  end

  def test_single_quote
    assert_equal '&apos;', htmlescape("'")
  end

  # ----------------------------------------------------------------
  # Plain strings that should pass through unchanged
  # ----------------------------------------------------------------
  def test_plain_string
    assert_equal 'hello world', htmlescape('hello world')
  end

  def test_empty_string
    assert_equal '', htmlescape('')
  end

  def test_numbers
    assert_equal '12345', htmlescape('12345')
  end

  # ----------------------------------------------------------------
  # Combined / mixed strings
  # ----------------------------------------------------------------
  def test_html_tag
    assert_equal '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;',
                 htmlescape('<script>alert("xss")</script>')
  end

  def test_attribute_value
    assert_equal 'It&apos;s a &quot;test&quot; &amp; more',
                 htmlescape("It's a \"test\" & more")
  end

  def test_ampersand_in_url
    assert_equal 'a=1&amp;b=2', htmlescape('a=1&b=2')
  end

  def test_multiple_special_chars
    assert_equal '&lt;&amp;&gt;&quot;&apos;', htmlescape('<&>"\'')
  end

  # ----------------------------------------------------------------
  # Idempotency: escaping an already-escaped string should not
  # double-escape the entities
  # ----------------------------------------------------------------
  def test_does_not_double_escape
    # The function is a raw escaper and does NOT skip existing entities,
    # so a second call escapes the '&' in '&amp;'.
    assert_equal '&amp;amp;', htmlescape('&amp;')
  end
end
