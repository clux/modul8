var path = require('path')
  , fs = require('fs')
  , coffee = require('coffee-script') // TODO: remove
  , dir = fs.realpathSync();

// internal error shortcut
// prepends a line to the stacktrace, so look at the previous one
exports.error = function (msg) {
  throw new Error("modul8 " + msg);
};

// shortcutted because it is used so much
exports.read = function (name) {
  return fs.readFileSync(name, 'utf8');
};

exports.makeCompiler = function (external) {
  if (!external) {
    external = {};
  }

  return function (file, bare) {
    if (bare === undefined) {
      bare = true;
    }
    var ext = path.extname(file)
      , raw = exports.read(file);

    if (ext === '.js') {
      return raw;
    }

    // TODO: force register this
    if (ext === '.coffee') {
      return coffee.compile(raw, {
        bare: bare
      });
    }

    var compiler = external[ext];
    if (compiler && {}.toString.call(compiler) === '[object Function]') {
      return compiler(raw, bare);
    }
    exports.error('cannot compile ' + file + ' - no compiler registered for this extension');
  };
};

exports.exists = function (file) {
  try {
    var stat = fs.statSync(file);
    return !stat.isDirectory();
  } catch (e) {
    return false;
  }
};
