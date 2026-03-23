// This file is licensed under the MIT License (MIT) available on
// http://opensource.org/licenses/MIT.

// Unit tests for pure logic functions from js/walletSelector.js
// Run with: node test/unit/test_walletSelector.js

'use strict';

var assert = require('assert');
var passed = 0;
var failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log('  PASS: ' + name);
    passed++;
  } catch (e) {
    console.log('  FAIL: ' + name);
    console.log('        ' + e.message);
    failed++;
  }
}

// ---------------------------------------------------------------------------
// Functions under test – copied verbatim from js/walletSelector.js
// The only external dependency for these functions is `window.location.href`
// (for updateQueryStringParameter) and `location.search`
// (for queryStringToArray / getUrlParameter), which we mock below.
// ---------------------------------------------------------------------------

// Mock globals used by the functions
var location = { search: '', href: 'http://example.com/' };
var window = { location: location };

function queryStringToArray() {
  var categories = ['platform', 'user', 'important', 'features'];
  var result = [];
  var pairs = location.search.slice(1).split('&');
  pairs.forEach(function(pair) {
    pair = pair.split('=');
    if (pair[1] && categories.indexOf(pair[0]) > -1) result = result.concat(pair[1].split(','));
  });
  return result;
}

function getUrlParameter(name) {
  name = name.replace(/[\[]/, '\\[').replace(/[\]]/, '\\]');
  var regex = new RegExp('[\\?&]' + name + '=([^&#]*)');
  var results = regex.exec(location.search);
  return results === null ? '' : decodeURIComponent(results[1].replace(/\+/g, ' '));
}

function updateQueryStringParameter(key, value) {
  var uri = window.location.href;
  var re = new RegExp('([?&])' + key + '=.*?(&|$)', 'i');
  var separator = uri.indexOf('?') !== -1 ? '&' : '?';
  if (uri.match(re)) {
    return uri.replace(re, '$1' + key + '=' + value + '$2');
  } else {
    return uri + separator + key + '=' + value;
  }
}

function checkIfFiltersInclude(categories, filters) {
  for (var i = 0; i < filters.length; i++) {
    var filter = filters[i];
    if (categories.indexOf(filter) === -1 && filter !== '') return false;
  }
  return true;
}

function renderCheckboxesHTML(filters, position) {
  filters = filters.split(',');
  var template = '<div class="checkboxes-acc-selected"><p class="checkboxes-acc-selected-text">%value%</p><button class="checkboxes-acc-selected-remove" data-checkbox-remove="%attribute%"><img src="/img/icons/close-btn.svg" alt="close"></button></div>';
  position.innerHTML = '';
  filters.forEach(function(filter) {
    var html = template.replace('%value%', filter.split('_').join(' '));
    html = html.replace('%attribute%', filter);
    position.innerHTML += html;
  });
}

function collectCheckedInputsValues(selectedInputs) {
  var selectedInputsValues = [];
  for (var i = 0; i < selectedInputs.length; i++) {
    var selectedInput = selectedInputs[i];
    selectedInputsValues.push(selectedInput.value);
  }
  return selectedInputsValues;
}

// ---------------------------------------------------------------------------
// Tests for checkIfFiltersInclude
// ---------------------------------------------------------------------------
console.log('\ncheckIfFiltersInclude tests:');

test('returns true when filters list is empty', function() {
  assert.strictEqual(checkIfFiltersInclude(['desktop', 'mobile'], []), true);
});

test('returns true when all filters are in categories', function() {
  assert.strictEqual(checkIfFiltersInclude(['desktop', 'mobile', 'linux'], ['desktop', 'linux']), true);
});

test('returns false when a filter is not in categories', function() {
  assert.strictEqual(checkIfFiltersInclude(['desktop', 'mobile'], ['hardware']), false);
});

test('returns false when one of multiple filters is missing', function() {
  assert.strictEqual(checkIfFiltersInclude(['desktop', 'mobile'], ['desktop', 'hardware']), false);
});

test('treats empty string filter as always passing', function() {
  assert.strictEqual(checkIfFiltersInclude(['desktop'], ['']), true);
});

test('returns true when categories list equals filters list', function() {
  assert.strictEqual(checkIfFiltersInclude(['a', 'b', 'c'], ['a', 'b', 'c']), true);
});

test('returns false when categories is empty and filter is non-empty', function() {
  assert.strictEqual(checkIfFiltersInclude([], ['desktop']), false);
});

// ---------------------------------------------------------------------------
// Tests for updateQueryStringParameter
// ---------------------------------------------------------------------------
console.log('\nupdateQueryStringParameter tests:');

test('adds parameter to URL with no query string', function() {
  window.location.href = 'http://example.com/wallets';
  var result = updateQueryStringParameter('platform', 'desktop');
  assert.ok(result.indexOf('platform=desktop') !== -1);
  assert.ok(result.indexOf('?') !== -1);
});

test('adds parameter to URL that already has a query string', function() {
  window.location.href = 'http://example.com/?foo=bar';
  var result = updateQueryStringParameter('platform', 'mobile');
  assert.ok(result.indexOf('platform=mobile') !== -1);
  assert.ok(result.indexOf('foo=bar') !== -1);
});

test('updates existing parameter value', function() {
  window.location.href = 'http://example.com/?platform=desktop';
  var result = updateQueryStringParameter('platform', 'mobile');
  assert.ok(result.indexOf('platform=mobile') !== -1);
  assert.ok(result.indexOf('platform=desktop') === -1);
});

test('preserves other parameters when updating one', function() {
  window.location.href = 'http://example.com/?platform=desktop&user=beginner';
  var result = updateQueryStringParameter('platform', 'mobile');
  assert.ok(result.indexOf('user=beginner') !== -1);
  assert.ok(result.indexOf('platform=mobile') !== -1);
});

test('handles URL with hash fragment', function() {
  window.location.href = 'http://example.com/page#section';
  var result = updateQueryStringParameter('step', '2');
  assert.ok(result.indexOf('step=2') !== -1);
});

// ---------------------------------------------------------------------------
// Tests for getUrlParameter
// ---------------------------------------------------------------------------
console.log('\ngetUrlParameter tests:');

test('returns empty string when parameter is absent', function() {
  location.search = '?foo=bar';
  assert.strictEqual(getUrlParameter('missing'), '');
});

test('returns value for a present parameter', function() {
  location.search = '?platform=desktop';
  assert.strictEqual(getUrlParameter('platform'), 'desktop');
});

test('returns value for the second of multiple parameters', function() {
  location.search = '?platform=desktop&user=beginner';
  assert.strictEqual(getUrlParameter('user'), 'beginner');
});

test('decodes percent-encoded values', function() {
  location.search = '?platform=my%20wallet';
  assert.strictEqual(getUrlParameter('platform'), 'my wallet');
});

test('replaces plus signs with spaces', function() {
  location.search = '?platform=my+wallet';
  assert.strictEqual(getUrlParameter('platform'), 'my wallet');
});

test('returns empty string when search is empty', function() {
  location.search = '';
  assert.strictEqual(getUrlParameter('platform'), '');
});

// ---------------------------------------------------------------------------
// Tests for queryStringToArray
// ---------------------------------------------------------------------------
console.log('\nqueryStringToArray tests:');

test('returns empty array when no recognised categories are present', function() {
  location.search = '?step=2';
  var result = queryStringToArray();
  assert.deepStrictEqual(result, []);
});

test('returns single value for a recognised category', function() {
  location.search = '?platform=desktop';
  var result = queryStringToArray();
  assert.ok(result.indexOf('desktop') !== -1);
});

test('splits comma-separated values for a single category', function() {
  location.search = '?important=bech32,segwit';
  var result = queryStringToArray();
  assert.ok(result.indexOf('bech32') !== -1);
  assert.ok(result.indexOf('segwit') !== -1);
});

test('collects values from multiple recognised categories', function() {
  location.search = '?platform=desktop&user=beginner';
  var result = queryStringToArray();
  assert.ok(result.indexOf('desktop') !== -1);
  assert.ok(result.indexOf('beginner') !== -1);
});

test('ignores unrecognised parameter keys', function() {
  location.search = '?unknown=value&platform=mobile';
  var result = queryStringToArray();
  assert.ok(result.indexOf('value') === -1);
  assert.ok(result.indexOf('mobile') !== -1);
});

test('returns empty array when search is empty', function() {
  location.search = '';
  assert.deepStrictEqual(queryStringToArray(), []);
});

// ---------------------------------------------------------------------------
// Tests for renderCheckboxesHTML
// ---------------------------------------------------------------------------
console.log('\nrenderCheckboxesHTML tests:');

test('generates HTML for a single filter', function() {
  var position = { innerHTML: '' };
  renderCheckboxesHTML('bech32', position);
  assert.ok(position.innerHTML.indexOf('bech32') !== -1);
  assert.ok(position.innerHTML.indexOf('data-checkbox-remove="bech32"') !== -1);
});

test('replaces underscores with spaces in displayed text', function() {
  var position = { innerHTML: '' };
  renderCheckboxesHTML('full_node', position);
  assert.ok(position.innerHTML.indexOf('full node') !== -1);
});

test('generates HTML for multiple comma-separated filters', function() {
  var position = { innerHTML: '' };
  renderCheckboxesHTML('bech32,segwit', position);
  assert.ok(position.innerHTML.indexOf('bech32') !== -1);
  assert.ok(position.innerHTML.indexOf('segwit') !== -1);
});

test('clears previous content before rendering', function() {
  var position = { innerHTML: 'old content' };
  renderCheckboxesHTML('new_filter', position);
  assert.ok(position.innerHTML.indexOf('old content') === -1);
  assert.ok(position.innerHTML.indexOf('new filter') !== -1);
});

// ---------------------------------------------------------------------------
// Tests for collectCheckedInputsValues
// ---------------------------------------------------------------------------
console.log('\ncollectCheckedInputsValues tests:');

test('returns empty array for empty input list', function() {
  assert.deepStrictEqual(collectCheckedInputsValues([]), []);
});

test('collects values from an array of input objects', function() {
  var inputs = [{ value: 'desktop' }, { value: 'mobile' }];
  assert.deepStrictEqual(collectCheckedInputsValues(inputs), ['desktop', 'mobile']);
});

test('handles a single input', function() {
  var inputs = [{ value: 'hardware' }];
  assert.deepStrictEqual(collectCheckedInputsValues(inputs), ['hardware']);
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log('\n' + (passed + failed) + ' tests: ' + passed + ' passed, ' + failed + ' failed');
if (failed > 0) process.exit(1);
