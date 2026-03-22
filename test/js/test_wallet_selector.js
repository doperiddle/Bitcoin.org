// This file is licensed under the MIT License (MIT) available on
// http://opensource.org/licenses/MIT.

// Unit tests for pure utility functions in js/walletSelector.js.
//
// Functions tested:
//   - checkIfFiltersInclude(categories, filters)
//   - updateQueryStringParameter(key, value)
//   - getUrlParameter(name)               [reads location.search]
//   - queryStringToArray()                [reads location.search]
//
// Browser globals are provided via a lightweight sandbox so the file loads
// cleanly under Node.js without a full DOM.

'use strict';

var assert = require('assert');
var fs     = require('fs');
var path   = require('path');
var vm     = require('vm');

// ---------------------------------------------------------------------------
// Sandbox – minimal browser-environment stub
// ---------------------------------------------------------------------------

// A no-op DOM element that safely absorbs any method call on it.
function makeNullElement() {
  return {
    addEventListener: function () {},
    removeEventListener: function () {},
    getAttribute: function () { return null; },
    setAttribute: function () {},
    classList: { add: function () {}, remove: function () {}, toggle: function () {} },
    dataset: {},
    textContent: '',
    parentNode: null,
    scrollIntoView: function () {}
  };
}

// querySelectorAll stub – returns an empty array-like with forEach.
function emptyNodeList() {
  var list = [];
  list.forEach = Array.prototype.forEach;
  return list;
}

var sandbox = {
  window: {
    location: { href: 'http://example.com/', search: '', pathname: '/' },
    history:  { pushState: function () {} },
    addEventListener: function () {},
    innerHeight: 768,
    innerWidth:  1024
  },
  location: { href: 'http://example.com/', search: '', pathname: '/' },
  history:  { pushState: function () {} },
  document: {
    getElementById:    function () { return makeNullElement(); },
    querySelector:     function () { return null; },
    querySelectorAll:  function () { return emptyNodeList(); },
    documentElement:   { scrollTop: 0, scrollLeft: 0, clientHeight: 768, clientWidth: 1024 }
  },
  Array:       Array,
  Object:      Object,
  String:      String,
  Number:      Number,
  Boolean:     Boolean,
  RegExp:      RegExp,
  Math:        Math,
  Date:        Date,
  parseInt:    parseInt,
  parseFloat:  parseFloat,
  encodeURIComponent: encodeURIComponent,
  decodeURIComponent: decodeURIComponent,
  console:     console,
  setTimeout:  setTimeout,
  clearInterval: clearInterval,
  setInterval:   setInterval
};

// Keep window.location and location in sync.
sandbox.window.location = sandbox.location;
sandbox.window.history  = sandbox.history;

var selectorSource = fs.readFileSync(
  path.join(__dirname, '../../js/walletSelector.js'),
  'utf8'
);

vm.runInNewContext(selectorSource, sandbox);

var checkIfFiltersInclude      = sandbox.checkIfFiltersInclude;
var updateQueryStringParameter = sandbox.updateQueryStringParameter;
var getUrlParameter            = sandbox.getUrlParameter;
var queryStringToArray         = sandbox.queryStringToArray;

// ==========================================================================
// checkIfFiltersInclude(categories, filters)
// ==========================================================================

describe('walletSelector – checkIfFiltersInclude', function () {
  describe('returns true', function () {
    it('when filters list is empty', function () {
      assert.strictEqual(checkIfFiltersInclude(['desktop', 'mobile'], []), true);
    });

    it('when every filter is present in categories', function () {
      assert.strictEqual(
        checkIfFiltersInclude(['desktop', 'mobile', 'web'], ['desktop', 'web']),
        true
      );
    });

    it('when filters contain only empty strings', function () {
      // Empty strings are treated as wildcards (skipped in the loop).
      assert.strictEqual(checkIfFiltersInclude([], ['']), true);
    });

    it('when categories and filters match exactly', function () {
      assert.strictEqual(checkIfFiltersInclude(['hardware'], ['hardware']), true);
    });
  });

  describe('returns false', function () {
    it('when a filter is absent from categories', function () {
      assert.strictEqual(checkIfFiltersInclude(['desktop'], ['mobile']), false);
    });

    it('when only some filters match', function () {
      assert.strictEqual(
        checkIfFiltersInclude(['desktop', 'mobile'], ['desktop', 'hardware']),
        false
      );
    });

    it('when categories is empty and filter is non-empty', function () {
      assert.strictEqual(checkIfFiltersInclude([], ['desktop']), false);
    });
  });

  describe('edge cases', function () {
    it('is case-sensitive', function () {
      assert.strictEqual(checkIfFiltersInclude(['Desktop'], ['desktop']), false);
    });

    it('handles a single-element match', function () {
      assert.strictEqual(checkIfFiltersInclude(['ios', 'android'], ['ios']), true);
    });
  });
});

// ==========================================================================
// updateQueryStringParameter(key, value)
// ==========================================================================

describe('walletSelector – updateQueryStringParameter', function () {
  function withHref(href, fn) {
    sandbox.location.href        = href;
    sandbox.window.location.href = href;
    fn();
    sandbox.location.href        = 'http://example.com/';
    sandbox.window.location.href = 'http://example.com/';
  }

  it('adds first query parameter with ?', function () {
    withHref('http://example.com/wallets', function () {
      var result = updateQueryStringParameter('platform', 'desktop');
      assert.ok(result.indexOf('?platform=desktop') !== -1,
        'should use ? for first param');
    });
  });

  it('adds subsequent parameter with &', function () {
    withHref('http://example.com/wallets?platform=desktop', function () {
      var result = updateQueryStringParameter('user', 'beginner');
      assert.ok(result.indexOf('&user=beginner') !== -1,
        'should use & for additional params');
      assert.ok(result.indexOf('platform=desktop') !== -1,
        'existing param preserved');
    });
  });

  it('replaces existing parameter value', function () {
    withHref('http://example.com/?platform=mobile', function () {
      var result = updateQueryStringParameter('platform', 'desktop');
      assert.ok(result.indexOf('platform=desktop') !== -1, 'value replaced');
      assert.ok(result.indexOf('platform=mobile') === -1, 'old value removed');
    });
  });

  it('preserves other parameters when replacing one', function () {
    withHref('http://example.com/?platform=mobile&user=beginner', function () {
      var result = updateQueryStringParameter('platform', 'desktop');
      assert.ok(result.indexOf('user=beginner') !== -1, 'other params preserved');
      assert.ok(result.indexOf('platform=desktop') !== -1, 'target param updated');
    });
  });

  it('handles parameter names that are case-insensitive regex matches', function () {
    withHref('http://example.com/?PLATFORM=mobile', function () {
      var result = updateQueryStringParameter('PLATFORM', 'desktop');
      assert.ok(result.indexOf('PLATFORM=desktop') !== -1, 'param replaced');
    });
  });
});

// ==========================================================================
// getUrlParameter(name)
// ==========================================================================

describe('walletSelector – getUrlParameter', function () {
  function withSearch(search, fn) {
    sandbox.location.search        = search;
    sandbox.window.location.search = search;
    fn();
    sandbox.location.search        = '';
    sandbox.window.location.search = '';
  }

  it('returns the value of an existing parameter', function () {
    withSearch('?platform=desktop', function () {
      assert.strictEqual(getUrlParameter('platform'), 'desktop');
    });
  });

  it('returns empty string when parameter is absent', function () {
    withSearch('?platform=desktop', function () {
      assert.strictEqual(getUrlParameter('user'), '');
    });
  });

  it('returns empty string when query string is empty', function () {
    withSearch('', function () {
      assert.strictEqual(getUrlParameter('platform'), '');
    });
  });

  it('decodes URL-encoded values', function () {
    withSearch('?message=hello%20world', function () {
      assert.strictEqual(getUrlParameter('message'), 'hello world');
    });
  });

  it('converts + to space in values', function () {
    withSearch('?message=hello+world', function () {
      assert.strictEqual(getUrlParameter('message'), 'hello world');
    });
  });

  it('handles multiple parameters and picks the correct one', function () {
    withSearch('?platform=mobile&user=beginner&features=segwit', function () {
      assert.strictEqual(getUrlParameter('user'), 'beginner');
      assert.strictEqual(getUrlParameter('platform'), 'mobile');
      assert.strictEqual(getUrlParameter('features'), 'segwit');
    });
  });

  it('handles parameter at end of query string without trailing &', function () {
    withSearch('?step=3', function () {
      assert.strictEqual(getUrlParameter('step'), '3');
    });
  });

  it('handles square-bracket characters in parameter names', function () {
    // getUrlParameter escapes [ and ] in the name before building the regex.
    withSearch('?filter[]=desktop', function () {
      assert.strictEqual(getUrlParameter('filter[]'), 'desktop');
    });
  });
});

// ==========================================================================
// queryStringToArray()
// ==========================================================================

describe('walletSelector – queryStringToArray', function () {
  function withSearch(search, fn) {
    sandbox.location.search        = search;
    sandbox.window.location.search = search;
    fn();
    sandbox.location.search        = '';
    sandbox.window.location.search = '';
  }

  it('returns empty array when query string is empty', function () {
    withSearch('', function () {
      var result = queryStringToArray();
      assert.strictEqual(result.length, 0, 'should return empty array');
    });
  });

  it('includes values for known categories', function () {
    withSearch('?platform=desktop', function () {
      var result = queryStringToArray();
      assert.ok(result.indexOf('desktop') !== -1, 'should include desktop');
    });
  });

  it('ignores unknown query parameters', function () {
    withSearch('?unknown=foo&platform=mobile', function () {
      var result = queryStringToArray();
      assert.ok(result.indexOf('foo') === -1,     'unknown param value excluded');
      assert.ok(result.indexOf('mobile') !== -1,  'known param value included');
    });
  });

  it('splits comma-separated values within a parameter', function () {
    withSearch('?features=segwit,bech32', function () {
      var result = queryStringToArray();
      assert.ok(result.indexOf('segwit') !== -1, 'segwit should be present');
      assert.ok(result.indexOf('bech32') !== -1, 'bech32 should be present');
    });
  });

  it('includes all four recognised categories', function () {
    withSearch('?platform=mobile&user=beginner&important=control&features=segwit', function () {
      var result = queryStringToArray();
      assert.ok(result.indexOf('mobile') !== -1,    'platform included');
      assert.ok(result.indexOf('beginner') !== -1,  'user included');
      assert.ok(result.indexOf('control') !== -1,   'important included');
      assert.ok(result.indexOf('segwit') !== -1,    'features included');
    });
  });

  it('returns array even when only unrecognised params present', function () {
    withSearch('?foo=bar&baz=qux', function () {
      var result = queryStringToArray();
      assert.strictEqual(result.length, 0, 'should return empty array for unknown params');
    });
  });
});
