#!/usr/bin/env ruby
# This file is licensed under the MIT License (MIT) available on
# http://opensource.org/licenses/MIT.
#
# Runs all unit tests under test/unit/ and reports a combined pass/fail result.
# Ruby tests are executed with the standard test/unit runner; JavaScript tests
# are executed with Node.js.
#
# Exit code 0 = all tests passed, non-zero = one or more failures.
#
# Usage:
#   ruby test/run_tests.rb

require 'open3'

failures = []
test_dir = File.expand_path('../unit', __FILE__)

# ---------------------------------------------------------------------------
# Ruby tests
# ---------------------------------------------------------------------------
ruby_tests = Dir.glob(File.join(test_dir, 'test_*.rb'))
ruby_tests.each do |file|
  stdout, stderr, status = Open3.capture3('ruby', file)
  label = File.basename(file)
  if status.success?
    puts "[PASS] #{label}"
  else
    puts "[FAIL] #{label}"
    puts stdout unless stdout.strip.empty?
    puts stderr unless stderr.strip.empty?
    failures << label
  end
end

# ---------------------------------------------------------------------------
# JavaScript tests (Node.js required)
# ---------------------------------------------------------------------------
js_tests = Dir.glob(File.join(test_dir, 'test_*.js'))
js_tests.each do |file|
  stdout, stderr, status = Open3.capture3('node', file)
  label = File.basename(file)
  if status.success?
    puts "[PASS] #{label}"
  else
    puts "[FAIL] #{label}"
    puts stdout unless stdout.strip.empty?
    puts stderr unless stderr.strip.empty?
    failures << label
  end
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
total = ruby_tests.length + js_tests.length
puts "\n#{total} test files: #{total - failures.length} passed, #{failures.length} failed"

unless failures.empty?
  puts "Failed: #{failures.join(', ')}"
  exit 1
end
