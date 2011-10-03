(function() {
  var cssWrap, exists, fs, minifier, nib, path, read, stylus, _ref;
  fs = require('fs');
  path = require('path');
  stylus = require('stylus');
  nib = require('nib');
  _ref = require('./utils'), exists = _ref.exists, read = _ref.read;
  minifier = function(css) {
    var uglifycss;
    uglifycss = require('uglifycss');
    return uglifycss.processString(css, {
      maxLineLen: 0,
      expandVars: false,
      cuteComments: false
    });
  };
  cssWrap = function(style, name) {
    return name + "()\n  @css{\n" + style + "\n  }";
  };
  module.exports = function(o) {
    if (!o.target || !o.entryPoint) {
      throw new Error('brownie glaze requires a target and an entryPoint');
    }
    if (!exists(o.entryPoint)) {
      throw new Error('brownie glaze: entryPoint not found: tried: ' + o.entryPoint);
    }
    return stylus(read(o.entryPoint)).set('compress', o.minify).set('filename', o.entryPoint).use(nib())["import"]('nib').render(function(err, css) {
      if (err) {
        throw err;
      }
      if (!o.target) {
        return css;
      }
      return fs.writeFileSync(o.target, css);
    });
  };
}).call(this);
