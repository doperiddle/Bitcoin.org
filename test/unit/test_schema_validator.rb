# This file is licensed under the MIT License (MIT) available on
# http://opensource.org/licenses/MIT.

# Unit tests for the wallet YAML schema validation logic used by
# _contrib/schema-validator.rb
#
# These tests verify that valid wallet documents pass validation and that
# documents with missing or invalid fields are correctly rejected.
#
# Run with: ruby test/unit/test_schema_validator.rb

require 'test/unit'
require 'tmpdir'
require 'safe_yaml/load'
require 'json-schema'

SCHEMA_FILE = File.expand_path('../../quality-assurance/schemas/wallets.yaml', __dir__)

def load_schema
  SafeYAML.load(File.read(SCHEMA_FILE))
end

def validate_document(doc)
  schema = load_schema
  JSON::Validator.fully_validate(schema, doc)
end

class TestSchemaValidator < Test::Unit::TestCase

  # A minimal valid OS entry (all required fields from the schema)
  VALID_OS = {
    'name'       => 'windows',
    'text'       => 'wallettest',
    'link'       => 'https://example.com/download',
    'screenshot' => 'test.png',
    'features'   => 'bech32 segwit',
    'check'      => {
      'control'      => 'checkgoodcontrolfull',
      'validation'   => 'checkgoodvalidationfullnode',
      'transparency' => 'checkgoodtransparencydeterministic',
      'environment'  => 'checkfailenvironmentdesktop',
      'privacy'      => 'checkgoodprivacyimproved'
    }
  }

  # A minimal valid wallet document (all required fields present and valid)
  VALID_WALLET = {
    'id'         => 'testwallet',
    'title'      => 'Test Wallet',
    'titleshort' => 'TestW',
    'compat'     => 'desktop windows',
    'level'      => 1,
    'platform'   => [
      {
        'name' => 'desktop',
        'os'   => [VALID_OS]
      }
    ]
  }

  # ----------------------------------------------------------------
  # Valid documents
  # ----------------------------------------------------------------

  def test_valid_wallet_passes
    errors = validate_document(VALID_WALLET)
    assert_empty errors, "Expected no validation errors but got: #{errors.inspect}"
  end

  def test_valid_wallet_with_user_field
    doc = VALID_WALLET.merge('user' => 'beginner')
    errors = validate_document(doc)
    assert_empty errors
  end

  # ----------------------------------------------------------------
  # Missing required fields
  # ----------------------------------------------------------------

  def test_missing_id_fails
    doc = VALID_WALLET.reject { |k, _| k == 'id' }
    errors = validate_document(doc)
    refute_empty errors
  end

  def test_missing_title_fails
    doc = VALID_WALLET.reject { |k, _| k == 'title' }
    errors = validate_document(doc)
    refute_empty errors
  end

  def test_missing_titleshort_fails
    doc = VALID_WALLET.reject { |k, _| k == 'titleshort' }
    errors = validate_document(doc)
    refute_empty errors
  end

  def test_missing_compat_fails
    doc = VALID_WALLET.reject { |k, _| k == 'compat' }
    errors = validate_document(doc)
    refute_empty errors
  end

  def test_missing_level_fails
    doc = VALID_WALLET.reject { |k, _| k == 'level' }
    errors = validate_document(doc)
    refute_empty errors
  end

  def test_missing_platform_fails
    doc = VALID_WALLET.reject { |k, _| k == 'platform' }
    errors = validate_document(doc)
    refute_empty errors
  end

  # ----------------------------------------------------------------
  # Field type validation
  # ----------------------------------------------------------------

  def test_level_must_be_integer
    doc = VALID_WALLET.merge('level' => 'high')
    errors = validate_document(doc)
    refute_empty errors
  end

  def test_level_minimum_boundary
    # level 1 is the minimum allowed value
    doc = VALID_WALLET.merge('level' => 1)
    assert_empty validate_document(doc)
  end

  def test_level_below_minimum_fails
    doc = VALID_WALLET.merge('level' => 0)
    errors = validate_document(doc)
    refute_empty errors
  end

  def test_level_maximum_boundary
    # level 4 is the maximum allowed value
    doc = VALID_WALLET.merge('level' => 4)
    assert_empty validate_document(doc)
  end

  def test_level_above_maximum_fails
    doc = VALID_WALLET.merge('level' => 5)
    errors = validate_document(doc)
    refute_empty errors
  end

  # ----------------------------------------------------------------
  # String length constraints
  # ----------------------------------------------------------------

  def test_title_too_long_fails
    doc = VALID_WALLET.merge('title' => 'A' * 101)
    errors = validate_document(doc)
    refute_empty errors
  end

  def test_title_max_length_passes
    doc = VALID_WALLET.merge('title' => 'A' * 100)
    assert_empty validate_document(doc)
  end

  def test_titleshort_too_long_fails
    doc = VALID_WALLET.merge('titleshort' => 'A' * 21)
    errors = validate_document(doc)
    refute_empty errors
  end

  def test_titleshort_max_length_passes
    doc = VALID_WALLET.merge('titleshort' => 'A' * 20)
    assert_empty validate_document(doc)
  end

  def test_compat_empty_string_fails
    doc = VALID_WALLET.merge('compat' => '')
    errors = validate_document(doc)
    refute_empty errors
  end

  # ----------------------------------------------------------------
  # Enum constraints
  # ----------------------------------------------------------------

  def test_user_invalid_enum_fails
    doc = VALID_WALLET.merge('user' => 'advanced')
    errors = validate_document(doc)
    refute_empty errors
  end

  def test_user_valid_enum_passes
    doc = VALID_WALLET.merge('user' => 'beginner')
    assert_empty validate_document(doc)
  end
end
