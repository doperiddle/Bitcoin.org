# This file is licensed under the MIT License (MIT) available on
# http://opensource.org/licenses/MIT.

# Unit tests for the YAML schema-validation logic used by
# _contrib/schema-validator.rb.
#
# The validator loads a JSON-Schema (expressed as YAML) and validates wallet
# documents against it.  We test this using inline fixture data so no
# filesystem layout is assumed beyond the schema file itself.

require 'minitest/autorun'
require 'safe_yaml/load'
require 'json-schema'

SCHEMA_PATH = File.expand_path('../../quality-assurance/schemas/wallets.yaml', __dir__)

# ---------------------------------------------------------------------------
# Helper – build a minimal valid wallet hash that satisfies every *required*
# field in the schema.
# ---------------------------------------------------------------------------
def minimal_valid_wallet
  {
    'id'         => 'testwallet',
    'title'      => 'Test Wallet',
    'titleshort' => 'TestWlt',
    'compat'     => 'desktop windows',
    'level'      => 2,
    'platform'   => [
      {
        'name' => 'desktop',
        'os'   => [
          {
            'name'       => 'windows',
            'text'       => 'wallettest',
            'link'       => 'https://example.com/download',
            'screenshot' => 'test.png',
            'features'   => 'segwit legacy_addresses',
            'check'      => {
              'control'      => 'checkgoodcontrolfull',
              'validation'   => 'checkgoodvalidationfullnode',
              'transparency' => 'checkgoodtransparencydeterministic',
              'environment'  => 'checkfailenvironmentdesktop',
              'privacy'      => 'checkgoodprivacyimproved',
              'fees'         => 'checkgoodfeecontrolfull'
            }
          }
        ]
      }
    ]
  }
end

class TestSchemaValidator < Minitest::Test
  def setup
    file   = File.open(SCHEMA_PATH, 'r')
    @schema = SafeYAML.load(file)
    file.close
  end

  # -----------------------------------------------------------------------
  # Valid documents
  # -----------------------------------------------------------------------

  def test_minimal_valid_wallet_passes_schema
    errors = JSON::Validator.fully_validate(@schema, minimal_valid_wallet)
    assert_empty errors, "Expected no errors but got: #{errors.inspect}"
  end

  def test_valid_wallet_with_optional_user_field
    wallet = minimal_valid_wallet.merge('user' => 'beginner')
    errors = JSON::Validator.fully_validate(@schema, wallet)
    assert_empty errors, "Wallet with user='beginner' should be valid"
  end

  def test_valid_wallet_all_security_levels
    [1, 2, 3, 4].each do |lvl|
      wallet = minimal_valid_wallet.merge('level' => lvl)
      errors = JSON::Validator.fully_validate(@schema, wallet)
      assert_empty errors, "Level #{lvl} should be valid"
    end
  end

  # -----------------------------------------------------------------------
  # Missing required top-level fields
  # -----------------------------------------------------------------------

  def test_missing_id_fails_validation
    wallet = minimal_valid_wallet.tap { |w| w.delete('id') }
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'Missing id should fail validation'
  end

  def test_missing_title_fails_validation
    wallet = minimal_valid_wallet.tap { |w| w.delete('title') }
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'Missing title should fail validation'
  end

  def test_missing_titleshort_fails_validation
    wallet = minimal_valid_wallet.tap { |w| w.delete('titleshort') }
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'Missing titleshort should fail validation'
  end

  def test_missing_compat_fails_validation
    wallet = minimal_valid_wallet.tap { |w| w.delete('compat') }
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'Missing compat should fail validation'
  end

  def test_missing_level_fails_validation
    wallet = minimal_valid_wallet.tap { |w| w.delete('level') }
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'Missing level should fail validation'
  end

  def test_missing_platform_fails_validation
    wallet = minimal_valid_wallet.tap { |w| w.delete('platform') }
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'Missing platform should fail validation'
  end

  # -----------------------------------------------------------------------
  # Field-type violations
  # -----------------------------------------------------------------------

  def test_level_below_minimum_fails
    wallet = minimal_valid_wallet.merge('level' => 0)
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'level=0 should fail (minimum is 1)'
  end

  def test_level_above_maximum_fails
    wallet = minimal_valid_wallet.merge('level' => 5)
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'level=5 should fail (maximum is 4)'
  end

  def test_level_as_string_fails
    wallet = minimal_valid_wallet.merge('level' => '2')
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'level as string should fail (must be integer)'
  end

  def test_title_empty_string_fails
    wallet = minimal_valid_wallet.merge('title' => '')
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'Empty title should fail (minLength: 1)'
  end

  def test_titleshort_empty_string_fails
    wallet = minimal_valid_wallet.merge('titleshort' => '')
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'Empty titleshort should fail (minLength: 1)'
  end

  def test_titleshort_too_long_fails
    wallet = minimal_valid_wallet.merge('titleshort' => 'A' * 21)
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'titleshort > 20 chars should fail (maxLength: 20)'
  end

  def test_title_too_long_fails
    wallet = minimal_valid_wallet.merge('title' => 'A' * 101)
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, 'title > 100 chars should fail (maxLength: 100)'
  end

  def test_invalid_user_value_fails
    wallet = minimal_valid_wallet.merge('user' => 'expert')
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, "user='expert' should fail (only 'beginner' is allowed)"
  end

  # -----------------------------------------------------------------------
  # Platform entries
  # -----------------------------------------------------------------------

  def test_invalid_platform_name_fails
    wallet = minimal_valid_wallet
    wallet['platform'][0]['name'] = 'smartwatch'
    errors = JSON::Validator.fully_validate(@schema, wallet)
    refute_empty errors, "Platform name 'smartwatch' should fail"
  end

  def test_valid_mobile_platform_name_passes
    os_entry = minimal_valid_wallet['platform'][0]['os'][0].merge('name' => 'android')
    wallet = minimal_valid_wallet
    wallet['platform'] = [{ 'name' => 'mobile', 'os' => [os_entry] }]
    errors = JSON::Validator.fully_validate(@schema, wallet)
    assert_empty errors, "Mobile platform with android OS should be valid"
  end

  def test_valid_web_platform_name_passes
    os_entry = minimal_valid_wallet['platform'][0]['os'][0].merge('name' => 'web')
    wallet = minimal_valid_wallet
    wallet['platform'] = [{ 'name' => 'web', 'os' => [os_entry] }]
    errors = JSON::Validator.fully_validate(@schema, wallet)
    assert_empty errors, "Web platform should be valid"
  end

  # -----------------------------------------------------------------------
  # Actual wallet files in the repository must pass the schema
  # -----------------------------------------------------------------------

  def test_all_wallet_files_pass_schema
    wallets_dir = File.expand_path('../../_wallets', __dir__)
    wallet_files = Dir.glob(File.join(wallets_dir, '*.md'))
    refute_empty wallet_files, 'Expected to find wallet .md files'

    wallet_files.each do |path|
      content = File.read(path)
      # Strip the YAML front matter
      yaml_str = content.split('---', 3)[1]
      next if yaml_str.nil?

      document = SafeYAML.load(yaml_str)
      errors = JSON::Validator.fully_validate(@schema, document)
      assert_empty errors, "#{File.basename(path)} failed schema validation: #{errors.inspect}"
    end
  end
end
