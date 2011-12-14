var toStr = Object.prototype.toString;

// All JS types that can be simply tested with toStr
var types = [
    'Function'
  , 'Object'    // Object(obj) === obj is also true for other things like noop
  , 'Date'
  , 'Number'
  , 'String'
  , 'Boolean'
  , 'RegExp'
  , 'Undefined' // should not use this - undefined can be redefined
  , 'Arguments' // should probably not use this - arguments going away
  //, 'Null'    // standard test does not work on 0.4
];

types.forEach(function (type) {
  var expected = '[object ' + type + ']';
  exports['is' + type] = function (o) {
    return toStr.call(o) === expected;
  };
});

// Do these faster
exports.isArray = function (o) {
  return Array.isArray(o);
};

exports.isNull = function (o) {
  return o === null;
};

// This would not even work as NaN maps to '[object Number]'
// However, NaN is the only value for which === is not reflexive
exports.isNaN = function (o) {
  return o !== o;
};
