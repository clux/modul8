var fs = require('fs')
  , path = require('path')
  , join = require('path').join;

fs.existsSync || (fs.existsSync = path.existsSync);

var modul8 = require('./lib/api');
modul8.minifier   = require('./lib/plugins/minifier');
modul8.testcutter = require('./lib/plugins/testcutter');
modul8.version    = require('./package').version;

module.exports = modul8;
