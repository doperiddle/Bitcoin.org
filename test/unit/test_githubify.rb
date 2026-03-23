# This file is licensed under the MIT License (MIT) available on
# http://opensource.org/licenses/MIT.

# Unit tests for the githubify Liquid block tag in _plugins/githubify.rb
# Run with: ruby test/unit/test_githubify.rb

require 'test/unit'

# ---------------------------------------------------------------------------
# Minimal stubs – keep them as thin as possible to avoid interfering with
# the logic under test.
# ---------------------------------------------------------------------------
module Liquid
  class Block
    def initialize(tag_name, text, tokens)
      @tag_name = tag_name
      @text = text
    end

    # Subclasses override render(); we store body text via set_body.
    def render(context); @body || ''; end
  end

  module Template
    def self.register_tag(name, klass); end
  end
end

module Jekyll; end

# Suppress the "plugin disabled" print when ENABLED_PLUGINS env var is set
ENV.delete('ENABLED_PLUGINS')

require_relative '../../_plugins/githubify'

# ---------------------------------------------------------------------------
# Helper: render a GitHubifyBlock with a given body and repository URL
# ---------------------------------------------------------------------------
def render_githubify(repo_url, body)
  block = Jekyll::GitHubifyBlock.new('githubify', repo_url, [])
  # Inject body text so the parent Liquid::Block#render returns it
  block.instance_variable_set(:@body, body)
  block.render(nil)
end

class TestGithubify < Test::Unit::TestCase

  REPO = 'https://github.com/bitcoin/bitcoin'

  # ----------------------------------------------------------------
  # Pull-request / issue references (#NNN)
  # ----------------------------------------------------------------

  def test_pr_two_digits
    result = render_githubify(REPO, 'Fixed in #12')
    assert_equal(
      "Fixed in <a href=\"#{REPO}/pull/12\">#12</a>",
      result
    )
  end

  def test_pr_three_digits
    result = render_githubify(REPO, 'See #1234')
    assert_equal(
      "See <a href=\"#{REPO}/pull/1234\">#1234</a>",
      result
    )
  end

  def test_pr_large_number
    result = render_githubify(REPO, 'Related to #98765')
    assert_equal(
      "Related to <a href=\"#{REPO}/pull/98765\">#98765</a>",
      result
    )
  end

  def test_single_digit_not_linked
    # Only two-or-more digit issue numbers should be converted
    result = render_githubify(REPO, 'Fixed in #9')
    assert_equal 'Fixed in #9', result
  end

  def test_multiple_prs
    result = render_githubify(REPO, '#11 and #22')
    assert_equal(
      "<a href=\"#{REPO}/pull/11\">#11</a> and <a href=\"#{REPO}/pull/22\">#22</a>",
      result
    )
  end

  # ----------------------------------------------------------------
  # Commit hash references (`7-10 hex chars`)
  # ----------------------------------------------------------------

  def test_commit_seven_chars
    result = render_githubify(REPO, 'Commit `abc1234`')
    assert_equal(
      "Commit <a href=\"#{REPO}/commit/abc1234\">`abc1234`</a>",
      result
    )
  end

  def test_commit_ten_chars
    result = render_githubify(REPO, 'See `0123456789`')
    assert_equal(
      "See <a href=\"#{REPO}/commit/0123456789\">`0123456789`</a>",
      result
    )
  end

  def test_commit_too_short_not_linked
    # 6 hex chars should NOT be converted (minimum is 7)
    result = render_githubify(REPO, '`abcdef`')
    assert_equal '`abcdef`', result
  end

  def test_commit_too_long_not_linked
    # 11 hex chars should NOT be converted (maximum is 10)
    result = render_githubify(REPO, '`abcdef01234`')
    assert_equal '`abcdef01234`', result
  end

  def test_commit_non_hex_not_linked
    # Letters outside [0-9a-f] should not be treated as a commit hash
    result = render_githubify(REPO, '`ghijklm`')
    assert_equal '`ghijklm`', result
  end

  # ----------------------------------------------------------------
  # Mixed PR and commit in same block
  # ----------------------------------------------------------------

  def test_pr_and_commit_together
    result = render_githubify(REPO, 'PR #100 (`abc1234`)')
    assert_equal(
      "PR <a href=\"#{REPO}/pull/100\">#100</a> (<a href=\"#{REPO}/commit/abc1234\">`abc1234`</a>)",
      result
    )
  end

  # ----------------------------------------------------------------
  # Plain text passes through unchanged
  # ----------------------------------------------------------------

  def test_plain_text_unchanged
    text = 'Nothing special here.'
    assert_equal text, render_githubify(REPO, text)
  end

  def test_empty_body
    assert_equal '', render_githubify(REPO, '')
  end

  # ----------------------------------------------------------------
  # Repository URL is used correctly in links
  # ----------------------------------------------------------------

  def test_different_repository_url
    alt_repo = 'https://github.com/bitcoin-dot-org/bitcoin.org'
    result = render_githubify(alt_repo, '#42')
    assert_equal(
      "<a href=\"#{alt_repo}/pull/42\">#42</a>",
      result
    )
  end
end
