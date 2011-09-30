(function() {
  var fs, nib, path, stylus;
  fs = require('fs');
  path = require('path');
  stylus = require('stylus');
  nib = require('nib');
  module.exports = function(o) {
    if (!o.target) {
      throw new Error('brownie glaze requires a target and an entryPoint');
    }
    return stylus(fs.readFileSync(o.input, 'utf8')).set('compress', o.minify).set('filename', o.input).render(function(err, css) {
      var options, uglifycss;
      if (err) {
        throw New(Error(err));
      }
      if (i.minify) {
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
