// brain - zombie tap test helper
var zombie    = require('zombie')
  , singles = ['ok', 'isDefined', 'isUndefined']
  , doubles = ['eql', 'equal', 'deepEqual', 'type'];

function Brain (t) {
  this.t = t;
  this.browser = new zombie.Browser();
}
singles.forEach(function (s) {
  Brain.prototype[s] = function (statement, msg) {
    return this.t[s](this.browser.evaluate(statement), msg);
  };
});

doubles.forEach(function (d) {
  Brain.prototype[d] = function (statement, expected, msg) {
    return this.t[d](this.browser.evaluate(statement), expected, msg);
  };
});

// evaluate hook
Brain.prototype.do = function (statement) {
  return this.browser.evaluate(statement);
};

function factory (t) {
  return new Brain(t);
}

module.exports = factory;
