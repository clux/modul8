(function() {
  var coffee, compile, cutTests, exists, fs, path, read;
  path = require('path');
  fs = require('fs');
  coffee = require('coffee-script');
  read = function(name) {
    return fs.readFileSync(name, 'utf8');
  };
  compile = function(fileName) {
    switch (path.extname(fileName)) {
      case '.js':
        return read(fileName);
      case '.coffee':
        return coffee.compile(read(fileName), {
          bare: true
        });
      default:
        throw new Error("file: " + fileName + " does not have a valid javascript/coffeescript extension");
    }
  };
  exists = function(file) {
    try {
      fs.statSync(file);
      return true;
    } catch (e) {
      return false;
    }
  };
  cutTests = function(code) {
    return code.replace(/\n.*require.main[\w\W]*$/, '');
  };
  module.exports = {
    compile: compile,
    exists: exists,
    cutTests: cutTests,
    read: read
  };
}).call(this);
