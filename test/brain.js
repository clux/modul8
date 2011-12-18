var zombie    = require('zombie')
  , assert    = require('assert')
  , browser = new zombie.Browser();

// brain - browser assert helper


var singles = ['ok', 'isDefined', 'isUndefined']
  , doubles = ['eql', 'equal', 'includes', 'type'];

singles.forEach(function (s) {
  exports[s] = function (statement, msg) {
    return assert[s](browser.evaluate(statement), msg);
  };
});

doubles.forEach(function (d) {
  exports[d] = function (statement, expected, msg) {
    return assert[d](browser.evaluate(statement), expected, msg);
  };
});


// evaluate hook
exports.do = function (statement) {
  return browser.evaluate(statement);
};
