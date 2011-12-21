var fs = require('fs');

var modul8 = require('./lib/api');
modul8.minifier = require('./lib/plugins/minifier');
modul8.testcutter = require('./lib/plugins/testcutter');
modul8.version = JSON.parse(fs.readFileSync(__dirname+'/package.json','utf8')).version;

module.exports = modul8;
