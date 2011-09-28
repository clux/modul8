(function() {
  var anonWrap, cjsWrap, coffee, commonjs, compile, exists, fs, jQueryWrap, objCount, path;
  var __hasProp = Object.prototype.hasOwnProperty;
  path = require('path');
  fs = require('fs');
  coffee = require('coffee-script');
  jQueryWrap = function(code) {
    return '$(function(){' + code + '});';
  };
  anonWrap = function(code) {
    return '(function(){' + code + '})();';
  };
  cjsWrap = function(code, exportLocation) {
    var end, start;
    start = "var exports = " + exportLocation + ", module = {};";
    end = "if (module.exports) {" + exportLocation + " = module.exports;}";
    return start + code + end;
  };
  commonjs = function(file, baseDir, baseName) {
    var code;
    code = compile(baseDir + '/' + file).replace(/\n.*require.main[\w\W]*$/, '');
    return anonWrap(cjsWrap(code, "" + this.appName + "." + baseName + "." + (file.split(path.extname(file))[0].replace(/\//, '.'))));
  };
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
  objCount = function(obj) {
    var i, key;
    i = 0;
    for (key in obj) {
      if (!__hasProp.call(obj, key)) continue;
      i++;
    }
    return i;
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
    objCount: objCount,
    exists: exists,
    cjsWrap: cjsWrap,
    anonWrap: anonWrap,
    jQueryWrap: jQueryWrap
  };
  if (module === require.main) {
    console.log(JSON.stringify(listToTree(['/home/e/repos/dmjs/app/client/app.coffee', '/home/e/repos/dmjs/app/client/controllers/user.coffee'], '/home/e/repos/dmjs/app/')));
  }
}).call(this);
