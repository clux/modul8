require('coffee-script');
/*
 * App code might be CS, so we must require it at some point anyway.
 * By doing it here, we avoid having to compile the lib.
 */

var modul8 = require('./src/modul8.coffee');
modul8.minifier = require('./src/plugins/minifier.coffee');
modul8.testcutter = require('./src/plugins/testcutter.coffee');

module.exports = modul8;
