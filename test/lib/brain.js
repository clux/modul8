var zombie    = require('zombie')
  , assert    = require('assert');

// brain - browser assert helper

var singles = ['ok', 'isDefined', 'isUndefined']
  , doubles = ['eql', 'equal', 'includes', 'type'];


function Brain() {
  this.browser = new zombie.Browser();
}
singles.forEach(function (s) {
  Brain.prototype[s] = function (statement, msg) {
    return assert[s](this.browser.evaluate(statement), msg);
  };
});

doubles.forEach(function (d) {
  Brain.prototype[d] = function (statement, expected, msg) {
    return assert[d](this.browser.evaluate(statement), expected, msg);
  };
});

// evaluate hook
Brain.prototype.do = function (statement) {
  return this.browser.evaluate(statement);
};

function factory () {
  return new Brain();
}

module.exports = factory;
