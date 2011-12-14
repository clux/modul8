// example 'before' function
// coarsely strips inlined tests and test dependencies from code before analysis

module.exports = function(code) {
  return code.replace(/\n.*require.main[\w\W]*$/, ''); //TODO: improve this
};
