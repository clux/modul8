(function(){  window.monolith = "I am a huge library";
})()

var QQ = {"app":{},"shared":{},"data":{}};
var requireConfig = {"namespace":"QQ","domains":["app","shared"],"main":"app"};
(function(){var DataReg, DomReg, domains, isRelative, makeRequire, ns, toAbsPath;
ns = window[requireConfig.namespace];
domains = requireConfig.domains;
DataReg = /^data::(.*)/;
DomReg = /^(.*)::/;
isRelative = function(reqStr) {
  return reqStr.slice(0, 2) === './';
};
makeRequire = function(dom, pathName) {
  return function(reqStr) {
    var d, isRel, o, scannable, _i, _len;
    if (DataReg.test(reqStr)) {
      d = reqStr.match(DataReg)[1];
      if (ns.data[d]) {
        return ns.data[d];
      }
      return console.error("Unable to resolve data require for " + d);
    }
    if ((isRel = isRelative(reqStr))) {
      reqStr = toAbsPath(dom, pathName, reqStr.slice(2));
    }
    scannable = [dom].concat(domains.filter(function(e) {
      return e !== dom;
    }));
    if (isRel) {
      scannable = [dom];
    } else if (DomReg.test(reqStr)) {
      scannable = [reqStr.match(DomReg)[1]];
      reqStr = reqStr.split('::')[1];
    }
    reqStr = reqStr.split('.')[0];
    for (_i = 0, _len = scannable.length; _i < _len; _i++) {
      o = scannable[_i];
      if (ns[o][reqStr]) {
        return ns[o][reqStr];
      }
    }
    return console.error("Unable to resolve require for: " + reqStr);
  };
};
toAbsPath = function(domain, pathName, relReqStr) {
  var folders;
  folders = pathName.split('/').slice(0, -1);
  while (relReqStr.slice(0, 3) === '../') {
    folders = folders.slice(0, -1);
    relReqStr = relReqStr.slice(3);
  }
  return folders.concat(relReqStr.split('/')).join('/');
};
ns.define = function(name, domain, fn) {
  var d, module;
  d = ns[domain];
  if (!d[name]) {
    d[name] = {};
  }
  module = {};
  fn(makeRequire(domain, name), module, d[name]);
  if (module.exports) {
    delete d[name];
    d[name] = module.exports;
  }
};
ns.require = makeRequire(requireConfig.main, 'browser');})();
QQ.define('calc','shared',function(require, module, exports){module.exports = {
  divides: function(d, n) {
    return !(d % n);
  }
};});
QQ.define('validation','shared',function(require, module, exports){var divides;
divides = require('./calc').divides;
exports.isLeapYear = function(yr) {
  return divides(yr, 4) && (!divides(yr, 100) || divides(yr, 400));
};});
QQ.define('bigthing/sub2','app',function(require, module, exports){module.exports = function(str) {
  return console.log(str);
};});
QQ.define('helper','app',function(require, module, exports){var testRunner;
module.exports = function(str) {
  return console.log(str);
};});
QQ.define('bigthing/sub1','app',function(require, module, exports){var sub2;
sub2 = require('./sub2');
exports.doComplex = function(str) {
  return sub2(str + ' (sub1 added this, passing to sub2)');
};});
QQ.define('main','app',function(require, module, exports){var b, helper, m, v;
helper = require('./helper');
helper('hello from app via helper');
b = require('bigthing/sub1');
b.doComplex('app calls up to sub1');
v = require('validation.coffee');
console.log('2004 isLeapYear?', v.isLeapYear(2004));
m = monolith;
console.log(monolith);});