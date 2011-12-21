var fs      = require('fs')
  , mkdirp  = require('mkdirp').sync
  , rimraf  = require('rimraf').sync
  , path    = require('path')
  , join    = path.join
  , type    = require(join('..', '..', 'lib', 'type'));

/**
 * generate directory trees and files from an object recursively
 * an object as a value means key should be a directory
 * a string as a value means key should be a file
 */
module.exports = function (name, obj) {
  var root = join(__dirname, '..', name);
  try {
    rimraf(root);
  } catch (e) {}

  var mk = function (o, pos) {
    Object.keys(o).forEach(function (k) {
      var newPos = join(pos, k);
      if (type.isObject(o[k])) {
        mkdirp(newPos, '0755');
        mk(o[k], newPos);
      }
      else if (type.isString(o[k])) {
        fs.writeFileSync(newPos, o[k]);
      }
    });
  };
  mk(obj, root);
};
