require('coffee-script');
/*
 * App code might be CS, so we require it at some point anyway.
 * By doing it here, we thus avoid having to compile the lib.
 */

var modul8 = require('./src/bundle.coffee');
//TODO: loop over plugins and attach them to exports here

module.exports = modul8;
