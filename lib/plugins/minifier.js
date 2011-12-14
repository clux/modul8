// example 'after' function
// minifies javascript using UglifyJS

var u       = require('uglify-js')
  , uglify  = u.uglify
  , parser  = u.parser;

module.exports = function(code) {
  return uglify.gen_code(uglify.ast_squeeze(uglify.ast_mangle(parser.parse(code))));
};
