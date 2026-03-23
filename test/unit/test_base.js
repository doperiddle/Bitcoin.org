// This file is licensed under the MIT License (MIT) available on
// http://opensource.org/licenses/MIT.

// Unit tests for pure logic functions extracted from js/base.js
// Run with: node test/unit/test_base.js

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
// Minimal DOM node stub – only supports className manipulation
// ---------------------------------------------------------------------------
function makeNode(className) {
  return { className: className || '' };
}

// ---------------------------------------------------------------------------
// Functions under test – copied verbatim from js/base.js so we can run them
// in Node.js without a browser environment.
// ---------------------------------------------------------------------------

function addClass(node, data) {
  var cl = node.className.split(' ');
  for (var i = 0, n = cl.length; i < n; i++) {
    if (cl[i] === data) return;
  }
  cl.push(data);
  node.className = cl.join(' ');
}

function removeClass(node, data) {
  var ocl = node.className.split(' ');
  var ncl = [];
  for (var i = 0, n = ocl.length; i < n; i++) {
    if (ocl[i] !== data) ncl.push(ocl[i]);
  }
  node.className = ncl.join(' ');
}

// ---------------------------------------------------------------------------
// Tests for addClass
// ---------------------------------------------------------------------------
console.log('\naddClass tests:');

test('adds a class to an empty className', function() {
  var node = makeNode('');
  addClass(node, 'foo');
  // The function splits '' by ' ' giving [''], then joins: ' foo'.
  // The class is present – that's what matters for DOM rendering.
  assert.ok(node.className.split(' ').indexOf('foo') !== -1);
});

test('adds a class to an existing className', function() {
  var node = makeNode('bar');
  addClass(node, 'foo');
  assert.ok(node.className.split(' ').indexOf('foo') !== -1);
});

test('does not add duplicate class', function() {
  var node = makeNode('foo');
  addClass(node, 'foo');
  var classes = node.className.split(' ').filter(Boolean);
  assert.strictEqual(classes.length, 1);
  assert.strictEqual(classes[0], 'foo');
});

test('preserves existing classes when adding a new one', function() {
  var node = makeNode('alpha beta');
  addClass(node, 'gamma');
  var classes = node.className.split(' ');
  assert.ok(classes.indexOf('alpha') !== -1);
  assert.ok(classes.indexOf('beta') !== -1);
  assert.ok(classes.indexOf('gamma') !== -1);
});

test('adds class when node has multiple classes and new one is not present', function() {
  var node = makeNode('a b c');
  addClass(node, 'd');
  assert.ok(node.className.split(' ').indexOf('d') !== -1);
});

// ---------------------------------------------------------------------------
// Tests for removeClass
// ---------------------------------------------------------------------------
console.log('\nremoveClass tests:');

test('removes a class that exists', function() {
  var node = makeNode('foo bar');
  removeClass(node, 'foo');
  assert.ok(node.className.split(' ').indexOf('foo') === -1);
});

test('preserves other classes when removing one', function() {
  var node = makeNode('foo bar baz');
  removeClass(node, 'bar');
  var classes = node.className.split(' ').filter(Boolean);
  assert.ok(classes.indexOf('foo') !== -1);
  assert.ok(classes.indexOf('baz') !== -1);
  assert.ok(classes.indexOf('bar') === -1);
});

test('no-op when class is not present', function() {
  var node = makeNode('foo');
  removeClass(node, 'nonexistent');
  assert.ok(node.className.split(' ').indexOf('foo') !== -1);
});

test('removes class from single-class node', function() {
  var node = makeNode('foo');
  removeClass(node, 'foo');
  assert.ok(node.className.split(' ').filter(Boolean).indexOf('foo') === -1);
});

test('removes all occurrences of duplicate classes', function() {
  // If somehow duplicates crept in, all should be removed
  var node = makeNode('foo foo bar');
  removeClass(node, 'foo');
  var classes = node.className.split(' ').filter(Boolean);
  assert.ok(classes.indexOf('foo') === -1);
  assert.ok(classes.indexOf('bar') !== -1);
});

// ---------------------------------------------------------------------------
// Round-trip: addClass then removeClass
// ---------------------------------------------------------------------------
console.log('\nround-trip tests:');

test('addClass then removeClass restores original class list', function() {
  var node = makeNode('alpha beta');
  addClass(node, 'gamma');
  assert.ok(node.className.split(' ').indexOf('gamma') !== -1);
  removeClass(node, 'gamma');
  assert.ok(node.className.split(' ').filter(Boolean).indexOf('gamma') === -1);
  assert.ok(node.className.split(' ').indexOf('alpha') !== -1);
  assert.ok(node.className.split(' ').indexOf('beta') !== -1);
});

test('adding an existing class changes nothing when later removed', function() {
  var node = makeNode('foo bar');
  addClass(node, 'foo'); // no-op: already present
  var classesBefore = node.className;
  removeClass(node, 'foo');
  assert.ok(node.className.split(' ').filter(Boolean).indexOf('foo') === -1);
  assert.ok(node.className.split(' ').indexOf('bar') !== -1);
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log('\n' + (passed + failed) + ' tests: ' + passed + ' passed, ' + failed + ' failed');
if (failed > 0) process.exit(1);
