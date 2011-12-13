var toStr = Object.prototype.toString;

// All JS types that can be simply tested with toStr
var types = [
    'Function'
  , 'Object'
  , 'Array'
  , 'Date'
  , 'Number'
  , 'String'
  , 'Boolean'
  , 'Null'
  , 'RegExp'
  , 'Undefined' // should not use this - undefined can be redefined
  , 'Arguments' // should probably not use this - arguments going away
];

types.forEach(function (type) {
  var expected = '[object ' + type + ']';
  exports['is' + type] = function (what) {
    return toStr.call(what) === expected;
  };
});

// NaN maps to '[object Number]' and is the only value for which === is not reflexive
exports.isNaN = function (obj) {
  return obj !== obj;
};
