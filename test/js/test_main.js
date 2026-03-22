// This file is licensed under the MIT License (MIT) available on
// http://opensource.org/licenses/MIT.

// Unit tests for pure utility functions defined in js/main.js.
//
// Functions tested:
//   - generateDonationUrl(address, amountBtc, message)
//   - checkIfFiltersInclude(categories, filters)
//   - updateQueryStringParameter(key, value)   [uses window.location]
//   - handleDevDocsRedirect(name)              [uses window.location]
//
// DOM-dependent functions are exercised using a minimal window/document
// stub so they can run under Node.js without a full browser.

'use strict';

var assert = require('assert');
var fs     = require('fs');
var path   = require('path');
var vm     = require('vm');

// ---------------------------------------------------------------------------
// Load main.js into a controlled sandbox that provides just enough of the
// browser globals the file needs at *parse* time (not full DOM).
// ---------------------------------------------------------------------------
var mainJsSource = fs.readFileSync(
  path.join(__dirname, '../../js/main.js'),
  'utf8'
);

// Minimal stubs for globals referenced at the top-level of main.js.
var sandbox = {
  window: {
    location: { href: 'http://example.com/', search: '' },
    MoonPayWebSdk: {
      init: function () { return { show: function () {} }; }
    },
    innerHeight: 768,
    innerWidth: 1024,
    pageYOffset: 0,
    pageXOffset: 0,
    scrollTo: function () {},
    history: { pushState: function () {} }
  },
  document: {
    getElementById: function () { return null; },
    querySelector: function () { return null; },
    querySelectorAll: function () { return []; },
    documentElement: { scrollTop: 0, scrollLeft: 0, clientHeight: 768, clientWidth: 1024 },
    body: { getAttribute: function () { return null; }, setAttribute: function () {}, removeAttribute: function () {} },
    createElement: function () { return { style: {}, classList: { add: function() {}, remove: function() {} } }; }
  },
  history: { pushState: function () {} },
  location: { search: '', href: 'http://example.com/' },
  // jQuery stub – main.js uses $ in many places
  $: function () {
    var obj = {
      data: function () { return ''; },
      val:  function () { return ''; },
      on:   function () { return obj; },
      text: function () { return obj; },
      attr: function () { return obj; },
      each: function () { return obj; },
      empty: function () { return obj; },
      append: function () { return obj; },
      qrcode: function () {}
    };
    obj.ajax = function () { return { then: function () {} }; };
    return obj;
  },
  // Globals declared as externals in .jshintrc
  getEvent:    function (e) { return e; },
  addClass:    function () {},
  getStyle:    function () { return '0px'; },
  addEvent:    function () {},
  cancelEvent: function () {},
  removeClass: function () {},
  removeEvent: function () {},
  onTouchClick: function () {},
  isMobile:    function () { return false; },
  L:           {},
  // Standard globals
  console:     console,
  parseInt:    parseInt,
  parseFloat:  parseFloat,
  Math:        Math,
  Date:        Date,
  encodeURIComponent: encodeURIComponent,
  decodeURIComponent: decodeURIComponent,
  RegExp:      RegExp,
  Array:       Array,
  Object:      Object,
  String:      String,
  Boolean:     Boolean,
  Number:      Number,
  setTimeout:  setTimeout,
  clearInterval: clearInterval,
  setInterval:   setInterval
};

// Make window === sandbox.window so `window.location` and `location` both work.
sandbox.window.location = sandbox.location;
sandbox.window.history  = sandbox.history;
sandbox.window.scrollTo = function () {};

vm.runInNewContext(mainJsSource, sandbox);

// Convenience references to the functions under test.
var generateDonationUrl         = sandbox.generateDonationUrl;
var checkIfFiltersInclude       = sandbox.checkIfFiltersInclude;
var updateQueryStringParameter  = sandbox.updateQueryStringParameter;
var handleDevDocsRedirect       = sandbox.handleDevDocsRedirect;

// ==========================================================================
// generateDonationUrl(address, amountBtc, message)
// ==========================================================================

describe('generateDonationUrl', function () {
  describe('address only (no amount, no message)', function () {
    it('returns the bare address when amountBtc is NaN and message is empty', function () {
      var result = generateDonationUrl('1BpEi6DfDAUFd153wiGrvkiKW1LghNBqZx', 'not-a-number', '');
      assert.strictEqual(result, '1BpEi6DfDAUFd153wiGrvkiKW1LghNBqZx');
    });

    it('returns the bare address when amount is 0 but message is empty', function () {
      // parseFloat('0') is 0 which is falsy but NOT NaN – it gets appended.
      var result = generateDonationUrl('addr', '0', '');
      assert.strictEqual(result, 'addr?amount=0');
    });
  });

  describe('with a valid amount', function () {
    it('appends ?amount=<value> for a positive BTC amount', function () {
      var result = generateDonationUrl('addr', '0.5', '');
      assert.strictEqual(result, 'addr?amount=0.5');
    });

    it('parses and formats integer amounts as floats', function () {
      var result = generateDonationUrl('addr', '1', '');
      assert.strictEqual(result, 'addr?amount=1');
    });

    it('handles floating-point string amounts', function () {
      var result = generateDonationUrl('addr', '0.00100000', '');
      assert.strictEqual(result, 'addr?amount=0.001');
    });
  });

  describe('with a message', function () {
    it('appends ?message=<encoded> when no amount is provided', function () {
      var result = generateDonationUrl('addr', 'abc', 'donation');
      // 'abc' is not a number → NaN; only message appended.
      assert.strictEqual(result, 'addr?message=donation');
    });

    it('appends both amount and message when both are provided', function () {
      var result = generateDonationUrl('addr', '0.1', 'hello world');
      assert.strictEqual(result, 'addr?amount=0.1&message=hello%20world');
    });

    it('URL-encodes the message', function () {
      var result = generateDonationUrl('addr', '', 'test message');
      assert.ok(result.indexOf('test%20message') !== -1, 'spaces should be percent-encoded');
    });

    it('does not append message when message is empty string', function () {
      var result = generateDonationUrl('addr', '0.01', '');
      assert.strictEqual(result, 'addr?amount=0.01');
      assert.ok(result.indexOf('message') === -1, 'should not contain message key');
    });
  });

  describe('edge cases', function () {
    it('returns just the address when amount is empty string and message is empty', function () {
      var result = generateDonationUrl('addr', '', '');
      assert.strictEqual(result, 'addr');
    });

    it('handles a negative amount', function () {
      var result = generateDonationUrl('addr', '-0.5', '');
      assert.strictEqual(result, 'addr?amount=-0.5');
    });
  });
});

// ==========================================================================
// checkIfFiltersInclude(categories, filters)
// ==========================================================================

describe('checkIfFiltersInclude', function () {
  describe('returns true', function () {
    it('when filters array is empty', function () {
      assert.strictEqual(checkIfFiltersInclude(['a', 'b', 'c'], []), true);
    });

    it('when all filters are present in categories', function () {
      assert.strictEqual(checkIfFiltersInclude(['desktop', 'mobile', 'web'], ['desktop', 'mobile']), true);
    });

    it('when filters contain only empty strings (treated as wild-cards)', function () {
      assert.strictEqual(checkIfFiltersInclude([], ['']), true);
    });

    it('when a single filter matches', function () {
      assert.strictEqual(checkIfFiltersInclude(['android', 'ios'], ['android']), true);
    });

    it('when categories and filters are identical', function () {
      assert.strictEqual(checkIfFiltersInclude(['a'], ['a']), true);
    });
  });

  describe('returns false', function () {
    it('when a filter is not present in categories', function () {
      assert.strictEqual(checkIfFiltersInclude(['desktop', 'mobile'], ['web']), false);
    });

    it('when one of multiple filters is missing', function () {
      assert.strictEqual(checkIfFiltersInclude(['desktop', 'mobile'], ['desktop', 'hardware']), false);
    });

    it('when categories is empty and filter is non-empty', function () {
      assert.strictEqual(checkIfFiltersInclude([], ['desktop']), false);
    });
  });

  describe('edge cases', function () {
    it('is case-sensitive', function () {
      assert.strictEqual(checkIfFiltersInclude(['Desktop'], ['desktop']), false);
    });

    it('treats each filter independently', function () {
      // First filter matches, second does not.
      assert.strictEqual(checkIfFiltersInclude(['a', 'b'], ['a', 'c']), false);
    });
  });
});

// ==========================================================================
// updateQueryStringParameter(key, value)
// ==========================================================================

describe('updateQueryStringParameter', function () {
  // The function reads window.location.href, so we patch it per test.
  function withHref(href, fn) {
    sandbox.location.href         = href;
    sandbox.window.location.href  = href;
    fn();
    sandbox.location.href         = 'http://example.com/';
    sandbox.window.location.href  = 'http://example.com/';
  }

  it('adds a new query parameter when none exist', function () {
    withHref('http://example.com/page', function () {
      var result = updateQueryStringParameter('step', '2');
      assert.ok(result.indexOf('step=2') !== -1, 'should contain step=2');
    });
  });

  it('appends with & when query string already exists', function () {
    withHref('http://example.com/page?platform=desktop', function () {
      var result = updateQueryStringParameter('step', '2');
      assert.ok(result.indexOf('platform=desktop') !== -1, 'original param preserved');
      assert.ok(result.indexOf('step=2') !== -1, 'new param appended');
    });
  });

  it('replaces an existing parameter value', function () {
    withHref('http://example.com/?step=1', function () {
      var result = updateQueryStringParameter('step', '3');
      assert.ok(result.indexOf('step=3') !== -1, 'value should be updated');
      assert.ok(result.indexOf('step=1') === -1, 'old value should be gone');
    });
  });

  it('preserves other parameters when updating one', function () {
    withHref('http://example.com/?platform=mobile&step=1', function () {
      var result = updateQueryStringParameter('step', '5');
      assert.ok(result.indexOf('platform=mobile') !== -1, 'other params preserved');
      assert.ok(result.indexOf('step=5') !== -1, 'target param updated');
    });
  });
});

// ==========================================================================
// handleDevDocsRedirect(name) – redirect table lookup
// ==========================================================================

describe('handleDevDocsRedirect', function () {
  // We capture where the code tries to redirect by patching window.location.href.
  var redirectTarget;
  var originalHref;

  beforeEach(function () {
    redirectTarget = null;
    originalHref   = sandbox.window.location.href;

    // Intercept assignments to window.location.href
    Object.defineProperty(sandbox.window.location, 'href', {
      configurable: true,
      get: function () { return originalHref; },
      set: function (v) { redirectTarget = v; }
    });
  });

  afterEach(function () {
    // Restore plain property
    Object.defineProperty(sandbox.window.location, 'href', {
      configurable: true,
      writable: true,
      value: 'http://example.com/'
    });
    sandbox.location.href = 'http://example.com/';
  });

  it('redirects blockchain guide terms to blockchain-guide', function () {
    handleDevDocsRedirect('proof-of-work');
    assert.ok(redirectTarget && redirectTarget.indexOf('/en/blockchain-guide#proof-of-work') !== -1,
      'proof-of-work should redirect to blockchain-guide');
  });

  it('redirects transaction guide terms to transactions-guide', function () {
    handleDevDocsRedirect('p2pkh-script-validation');
    assert.ok(redirectTarget && redirectTarget.indexOf('/en/transactions-guide#p2pkh-script-validation') !== -1,
      'p2pkh-script-validation should redirect to transactions-guide');
  });

  it('redirects contracts guide terms to contracts-guide', function () {
    handleDevDocsRedirect('escrow-and-arbitration');
    assert.ok(redirectTarget && redirectTarget.indexOf('/en/contracts-guide#escrow-and-arbitration') !== -1,
      'escrow-and-arbitration should redirect to contracts-guide');
  });

  it('redirects wallets guide terms to wallets-guide', function () {
    handleDevDocsRedirect('wallet-programs');
    assert.ok(redirectTarget && redirectTarget.indexOf('/en/wallets-guide#wallet-programs') !== -1,
      'wallet-programs should redirect to wallets-guide');
  });

  it('redirects payment processing terms to payment-processing-guide', function () {
    handleDevDocsRedirect('pricing-orders');
    assert.ok(redirectTarget && redirectTarget.indexOf('/en/payment-processing-guide#pricing-orders') !== -1,
      'pricing-orders should redirect to payment-processing-guide');
  });

  it('redirects operating modes terms to operating-modes-guide', function () {
    handleDevDocsRedirect('full-node');
    assert.ok(redirectTarget && redirectTarget.indexOf('/en/operating-modes-guide#full-node') !== -1,
      'full-node should redirect to operating-modes-guide');
  });

  it('redirects p2p network terms to p2p-network-guide', function () {
    handleDevDocsRedirect('peer-discovery');
    assert.ok(redirectTarget && redirectTarget.indexOf('/en/p2p-network-guide#peer-discovery') !== -1,
      'peer-discovery should redirect to p2p-network-guide');
  });

  it('redirects mining guide terms to mining-guide', function () {
    handleDevDocsRedirect('solo-mining');
    assert.ok(redirectTarget && redirectTarget.indexOf('/en/mining-guide#solo-mining') !== -1,
      'solo-mining should redirect to mining-guide');
  });

  it('does not redirect an unknown term', function () {
    handleDevDocsRedirect('not-a-known-term');
    assert.strictEqual(redirectTarget, null, 'unknown terms should not trigger a redirect');
  });
});
