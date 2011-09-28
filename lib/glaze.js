(function() {
  var fs, path;
  fs = require('fs');
  path = require('path');
  module.exports = function(i) {
    var nib, stylus;
    stylus = require('stylus');
    nib = require('nib');
    return stylus(fs.readFileSync(i.input, 'utf8')).set('compress', i.minify).set('filename', i.input).render(function(err, css) {
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
      if (!i.target) {
        return css;
      }
      return fs.writeFileSync(i.target, css);
    });
  };
}).call(this);
