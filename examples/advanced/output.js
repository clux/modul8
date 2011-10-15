(function(){  window.monolith = "I am a huge library";
})();
(function(){window.QQ = {data:{}};
var _modul8RequireConfig = {"namespace":"QQ","domains":["app","shared"],"arbiters":{"monolith":["monolith"]},"logging":false,"main":"app","exts":["",".js",".coffee"]};
(function(){var a, arbiters, ary, base, domains, exports, exts, glob, makeRequire, name, ns, toAbsPath, _i, _j, _len, _len2, _ref;
var __indexOf = Array.prototype.indexOf || function(item) {
  for (var i = 0, l = this.length; i < l; i++) {
    if (this[i] === item) return i;
  }
  return -1;
};
base = _modul8RequireConfig;
ns = window[base.namespace];
domains = base.domains;
exts = base.exts;
exports = {};
for (_i = 0, _len = domains.length; _i < _len; _i++) {
  name = domains[_i];
  exports[name] = {};
}
exports.data = ns.data;
delete ns.data;
exports.M8 = {};
exports.external = {};
arbiters = [];
_ref = base.arbiters;
for (name in _ref) {
  ary = _ref[name];
  arbiters.push(name);
  a = window[name];
  for (_j = 0, _len2 = ary.length; _j < _len2; _j++) {
    glob = ary[_j];
    delete window[glob];
  }
  exports.M8[name] = a;
}
makeRequire = function(dom, pathName) {
  var DomReg, isRelative;
  DomReg = /^(.*)::/;
  isRelative = function(reqStr) {
    return reqStr.slice(0, 2) === './';
  };
  return function(reqStr) {
    var e, noTryFolder, o, scannable, _k, _l, _len3, _len4, _len5, _m;
    if (base.logging) {
      console.log("" + dom + ":" + pathName + " <- " + reqStr);
    }
    if (isRelative(reqStr)) {
      scannable = [dom];
      reqStr = toAbsPath(dom, pathName, reqStr.slice(2));
    } else if (DomReg.test(reqStr)) {
      scannable = [reqStr.match(DomReg)[1]];
      reqStr = reqStr.split('::')[1];
    } else if (__indexOf.call(arbiters, reqStr) >= 0) {
      scannable = ['M8'];
    } else {
      scannable = [dom].concat(domains.filter(function(e) {
        return e !== dom;
      }));
    }
    if (reqStr.slice(-1) === '/') {
      reqStr += 'index';
      noTryFolder = true;
    }
    for (_k = 0, _len3 = scannable.length; _k < _len3; _k++) {
      o = scannable[_k];
      for (_l = 0, _len4 = exts.length; _l < _len4; _l++) {
        e = exts[_l];
        if (exports[o][reqStr + e]) {
          return exports[o][reqStr + e];
        }
      }
      if (noTryFolder) {
        continue;
      }
      for (_m = 0, _len5 = exts.length; _m < _len5; _m++) {
        e = exts[_m];
        if (exports[o][reqStr + '/index' + e]) {
          return exports[o][reqStr + '/index' + e];
        }
      }
    }
    if (base.logging) {
      console.error("Unable to resolve require for: " + reqStr);
    }
    return null;
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
  var module;
  fn(makeRequire(domain, name), module = {}, exports[domain][name] = {});
  if (module.exports) {
    delete exports[domain][name];
    exports[domain][name] = module.exports;
  }
};
ns.inspect = function(domain) {
  console.log(exports[domain]);
};
ns.domains = function() {
  return domains.concat(['external']);
};
ns.require = makeRequire(base.main, 'CONSOLE');
exports.M8.data = ns.data = function(name, exported) {
  if (exports.data[name]) {
    delete exports.data[name];
  }
  if (exported) {
    exports.data[name] = exported;
  }
};
exports.M8.external = ns.external = function(name, exported) {
  if (exports.external[name]) {
    delete exports.exernal[name];
  }
  if (exported) {
    exports.extenal[name] = exported;
  }
};})();
QQ.define('calc.coffee','shared',function(require, module, exports){module.exports = {
  divides: function(d, n) {
    return !(d % n);
  }
};});
QQ.define('validation.coffee','shared',function(require, module, exports){var divides;
divides = require('./calc').divides;
exports.isLeapYear = function(yr) {
  return divides(yr, 4) && (!divides(yr, 100) || divides(yr, 400));
};});
(function(){QQ.define('bigthing/sub2.coffee','app',function(require, module, exports){module.exports = function(str) {
  return console.log(str);
};});
QQ.define('helper.coffee','app',function(require, module, exports){var testRunner;
module.exports = function(str) {
  return console.log(str);
};});
QQ.define('bigthing/sub1.coffee','app',function(require, module, exports){var sub2;
sub2 = require('./sub2');
exports.doComplex = function(str) {
  return sub2(str + ' (sub1 added this, passing to sub2)');
};});
QQ.define('main.coffee','app',function(require, module, exports){var b, helper, m, v;
helper = require('./helper');
helper('hello from app via helper');
b = require('bigthing/sub1');
b.doComplex('app calls up to sub1');
v = require('validation.coffee');
console.log('2004 isLeapYear?', v.isLeapYear(2004));
m = require('monolith');
console.log("monolith:" + m);});})();
})();