(function() {
  var coffee, compile, exists, fs, path;
  path = require('path');
  fs = require('fs');
  coffee = require('coffee-script');
  compile = function(fileName) {
    switch (path.extname(fileName)) {
      case '.js':
        return fs.readFileSync(fileName, 'utf8');
      case '.coffee':
        return coffee.compile(fs.readFileSync(fileName, 'utf8'), {
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
  module.exports = {
    compile: compile,
    exists: exists
  };
}).call(this);
