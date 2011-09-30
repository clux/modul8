(function() {
  var exists, fs, nib, path, read, stylus;
  fs = require('fs');
  path = require('path');
  stylus = require('stylus');
  nib = require('nib');
  exists = require('./utils').exists;
  read = function(name) {
    return fs.readFileSync(name, 'utf8');
  };
  module.exports = function(o) {
    if (!o.target || !o.entryPoint) {
      throw new Error('brownie glaze requires a target and an entryPoint');
    }
    if (!exists(o.entryPoint)) {
      throw new Error('brownie glaze: entryPoint not found: tried: ' + o.entryPoint);
    }
    return stylus(read(o.entryPoint)).set('compress', o.minify).set('filename', o.entryPoint).render(function(err, css) {
      var options, uglifycss;
      if (err) {
        throw new Error(err);
      }
      if (o.minify) {
        uglifycss = require('uglifycss');
        options = {
          maxLineLen: 0,
          expandVars: false,
          cuteComments: false
        };
        css = uglifycss.processString(css, options);
      }
      if (!o.target) {
        return css;
      }
      return fs.writeFileSync(o.target, css);
    });
  };
}).call(this);
