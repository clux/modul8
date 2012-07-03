var fs      = require('fs')
  , path    = require('path')
  , crypto  = require('crypto')
  , type    = require('typr')
  , eql     = require('deep-equal')
  , noop    = function () {};

function makeGuid(vals) {
  var str = vals.concat(fs.realpathSync()).map(function (v) {
    return v + '';
  }).join('_');
  return crypto.createHash('md5').update(str).digest("hex");
}

/**
 * Persist class
 *
 * @[in] file - path to where persist data is stored
 * @[in] keys - list of strings to scramble together with script load path as an internal guid
 * @[in] log  - log function (such as logule.get('debug') || console.log) for printing
 */
function Persist(cacheFile, keys, log) {
  var pdata = (cacheFile) ? JSON.parse(fs.readFileSync(cacheFile, 'utf8')) : {}
    , guid = makeGuid(keys);

  pdata[guid] = pdata[guid] || {};

  // this is the only member that needs access to the full object and the file
  this.save = function () {
    if (cacheFile) {
      fs.writeFileSync(cacheFile, JSON.stringify(pdata));
    }
  };

  // members need only know their config object
  this.cfg = pdata[guid];
  this.cfg.opts = this.cfg.opts || {};

  // was a logger passed down?
  this.log = (type.isFunction(log)) ? log : noop;
}

Persist.prototype.filesModified = function (fileList, doms, type) {
  var mTimesTracked = this.cfg[type] || {}
    , mTimesNew = {}
    , filesTracked = Object.keys(mTimesTracked)
    , that = this
    , i = 0
    , f;

  fileList.forEach(function (pair) {
    var d = pair[0]
      , f = pair[1];
    mTimesNew[d + '::' + f] = fs.statSync(path.join(doms[d], f)).mtime.valueOf();
  });
  var filesNew = Object.keys(mTimesNew);

  this.cfg[type] = mTimesNew;
  this.save();
  if (eql(mTimesTracked, {}) && !eql(mTimesNew, {})) {
    this.log("initializing " + type);
    return true;
  }

  for (i = 0; i < filesNew.length; i += 1) {
    f = filesNew[i];   // f is a key of mTimesNew => a uid
    var m = mTimesNew[f]; // m is a the value mTimesNew[f] => a mTime

    if (filesTracked.indexOf(f) < 0) {
      that.log("files added to " + type);
      return true;
    }
    if (mTimesTracked[f] !== m) {
      that.log("files updated in " + type);
      return true;
    }
  }
  for (i = 0; i < filesTracked.length; i += 1) {
    f = filesTracked[i]; // f is a key of mTimes
    if (filesNew.indexOf(f) < 0) {
      that.log("files removed from " + type);
      return true;
    }
  }

  return false;
};

Persist.prototype.objectModified = function (o) {
  if (eql(this.cfg.opts, JSON.parse(JSON.stringify(o)))) {
    return false;
  }
  this.cfg.opts = o;
  this.save();
  return true;
};


module.exports = function (a, b, c) {
  return new Persist(a, b, c);
};
