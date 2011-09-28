(function() {
  var DataReg, domains, fallback, isRelative, makeRequire, ns, toAbsPath;
  ns = window[requireConfig.namespace];
  domains = requireConfig.domains;
  fallback = ns.fallback;
  DataReg = /^data::/;
  isRelative = function(reqStr) {
    return reqStr.slice(0, 2) === './';
  };
  makeRequire = function(dom, pathName) {
    return function(reqStr) {
      var d, isRel, o, scannable, _i, _len;
      console.log("" + dom + ":" + pathName + " <- " + reqStr);
      if (DataReg.test(reqStr)) {
        d = reqStr.replace(DataReg, '');
        if (ns.data[d]) {
          return ns.data[d];
        }
        return console.error("Unable to resolve data require for " + d);
      }
      if ((isRel = isRelative(reqStr))) {
        reqStr = toAbsPath(dom, pathName, reqStr.slice(2));
      }
      scannable = isRel ? [dom] : [dom].concat(domains.filter(function(e) {
        return e !== dom;
      }));
      for (_i = 0, _len = scannable.length; _i < _len; _i++) {
        o = scannable[_i];
        if (ns[o][reqStr]) {
          return ns[o][reqStr];
        }
      }
      if (fallback && 'Function' === typeof fallback) {
        return fallback(reqStr);
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
  ns.require = makeRequire('client', 'browser');
}).call(this);
