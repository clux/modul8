var assert = require('assert')
  , t = require('../lib/type.js')
  , log = require('logule').sub('TYPES')
  , F = function () {};

exports['test type#partitioning'] = function () {
  // We expect the that the following arrays can be partitioned as follows
  var expected = {
    'Function'  : [ function () {}, F ]
  , 'Object'    : [ {}, new F(), {a: [1]} ]
  , 'Array'     : [ [], [1, '2'], [1, [2, [3]]], [13], [[[[]]]] ]
  , 'Date'      : [ new Date() ]
  , 'Number'    : [ 223434, 1 / 0, -Infinity, NaN, 0 / 0, Date.now(), Number('123'), 0, 1 ]
  , 'String'    : [ "str", String('str'), 5 + "arst" ]
  , 'Boolean'   : [ true, false, !5, !null, !undefined ]
  , 'Null'      : [ null ]
  , 'RegExp'    : [ /\//, new RegExp("/") ]
  , 'Undefined' : [ F['unknown_prop'], undefined ]
  , 'Arguments' : [ arguments ]
  };

  assert.ok(t.isFunction, 't.isFunction exists');
  var testCount = 1;

  Object.keys(expected).forEach(function (type) {
    var ary = expected[type];

    // Expect each key to exist on t
    assert.isDefined(t['is' + type], 'is' + type + ' isDefined');
    assert.ok(t.isFunction(t['is' + type]), 'isFunction(t.is' + type + ')');
    testCount += 2;

    // Expect each element of ary to satisfy t['is' + type]
    ary.forEach(function (e) {
      assert.ok(t['is' + type](e), 't.is' + type + ' of ' + Object.prototype.toString.call(e) + ' (' + e + ') is true');
      testCount += 1;
    });

    // Expect empty call to return true IFF type is 'Undefined'
    if (type === 'Undefined') {
      assert.ok(t['is' + type](), "empty call isUndefined");
    }
    else {
      assert.ok(!t['is' + type](), "empty call !is" + type);
    }
    testCount += 1;

    Object.keys(expected).forEach(function (innerType) {
      if (innerType === type) {
        return;
      }
      var innerAry = expected[innerType];
      // Expect each element of innerAry to not satisy t['is ' + type]
      innerAry.forEach(function (innerEl) {
        assert.ok(!t['is' + type](innerEl), innerEl + ' !is' + type);
        testCount += 1;
      });
    });

  });
  log.info('completed', testCount, 'type partitioning tests');
};
