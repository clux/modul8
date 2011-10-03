(function() {
  var exists, fs, minifier, nib, path, read, stylus;
  fs = require('fs');
  path = require('path');
  stylus = require('stylus');
  nib = require('nib');
  exists = require('./utils').exists;
  read = function(name) {
    return fs.readFileSync(name, 'utf8');
  };
  minifier = function(css) {
    var uglifycss;
    uglifycss = require('uglifycss');
    return uglifycss.processString(css, {
      maxLineLen: 0,
      expandVars: false,
      cuteComments: false
    });
  };
  module.exports = function(o) {
    if (!o.target || !o.entryPoint) {
      throw new Error('brownie glaze requires a target and an entryPoint');
    }
    if (!exists(o.entryPoint)) {
      throw new Error('brownie glaze: entryPoint not found: tried: ' + o.entryPoint);
    }
    return stylus(read(o.entryPoint)).set('compress', o.minify).set('filename', o.entryPoint).render(function(err, css) {
      var _ref;
      if (err) {
        throw new Error(err);
      }
      if (o.minify) {
        minifier = (_ref = o.minifier) != null ? _ref : minifier;
        if (!minifier instanceof Function) {
          throw new Error("brownie glaze: minifier must be a function");
        }
        css = minifier(css);
      }
      if (!o.target) {
        return css;
      }
      return fs.writeFileSync(o.target, css);
    });
  };
}).call(this);
