var path = require('path')
  , fs = require('fs')
  , logule = require('logule').sub('modul8').suppress('debug')
  , projName = ""
  , dir = fs.realpathSync();

exports.logule = logule;

exports.updateLogger = function (sub) {
  if (!logule.verify(sub)) {
    exports.error("got an invalid logule instance sent to logger - out of date?");
  }
  logule = sub;
  exports.logule = sub;
};

exports.updateProject = function (name) {
  projName = name;
};



// internal error shortcut
// prepends a line to the stacktrace, so look at the previous one
exports.error = function (msg) {
  var error = [];
  error.push("compile()");
  if (projName) {
    error.push("from '" + projName + "'");
  }
  error.push("failed for the following reason:");
  logule
    .error(error.join(' '))
    .error("")
    .error(msg)
    .error("")
    .error("If you feel this is a problem with modul8, please attach this output and following backtrace to: ")
    .error("http://www.github.com/clux/modul8/issues");
  throw new Error(msg);
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
