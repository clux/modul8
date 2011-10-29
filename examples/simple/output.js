(function(){
window.M8 = {data:{}};
var _modul8RequireConfig = {"namespace":"M8","domains":["app"],"arbiters":{"jQuery":["$","jQuery"]},"logging":false};
(function(){var DomReg, a, arbiters, ary, base, domains, exports, glob, makeRequire, name, ns, toAbsPath, _i, _j, _len, _len2, _ref;
base = _modul8RequireConfig;
ns = window[base.namespace];
domains = base.domains;
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
DomReg = /^(.*)::/;
makeRequire = function(dom, pathName) {
  return function(reqStr) {
    var o, scannable, skipFolder, _k, _len3;
    if (base.logging) {
      console.log("" + dom + ":" + pathName + " <- " + reqStr);
    }
    if (reqStr.slice(0, 2) === './') {
      scannable = [dom];
      reqStr = toAbsPath(dom, pathName, reqStr.slice(2));
    } else if (DomReg.test(reqStr)) {
      scannable = [reqStr.match(DomReg)[1]];
      reqStr = reqStr.split('::')[1];
    } else if (arbiters.indexOf(reqStr) >= 0) {
      scannable = ['M8'];
    } else {
      scannable = [dom].concat(domains.filter(function(e) {
        return e !== dom;
      }));
    }
    reqStr = reqStr.split('.')[0];
    if (reqStr.slice(-1) === '/') {
      reqStr += 'index';
      skipFolder = true;
    }
    for (_k = 0, _len3 = scannable.length; _k < _len3; _k++) {
      o = scannable[_k];
      if (exports[o][reqStr]) {
        return exports[o][reqStr];
      }
      if (!skipFolder && exports[o][reqStr + '/index']) {
        return exports[o][reqStr + '/index'];
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
ns.require = makeRequire('app', 'CONSOLE');
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

M8.require('M8::jQuery')(function(){M8.define('utils/validation','app',function(require, module, exports){exports.nameOk = function(name){
  return (name != 'jill');
};
});
M8.define('models/user','app',function(require, module, exports){var validation = require('utils/validation.js');

var User = {
  records : ['jack', 'jill'],

  fetch : function(){
    return this.records.filter(this.validate);
  },

  validate : function(user) {
    return validation.nameOk(user);
  }
};

module.exports = User;
});
M8.define('controllers/users','app',function(require, module, exports){var User = require('models/user');

var Users = {
  init : function(){
    return User.fetch();
  }
};

module.exports = Users;
});
M8.define('app','app',function(require, module, exports){var Users = require('controllers/users');
var $ = require('jQuery');

var App = {
  init: function(){
    $('#output').text( JSON.stringify(Users.init()) );
  }
}.init();
});});
})();