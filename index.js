var fs = require('fs')
  , join = require('path').join
  , modul8 = require('./lib/api');

modul8.minifier   = require('./lib/plugins/minifier');
modul8.testcutter = require('./lib/plugins/testcutter');
modul8.version    = require('./package').version;

module.exports = modul8;
