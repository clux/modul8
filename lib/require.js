/**
 * modul8 vVERSION
 */

var config    = REQUIRECONFIG // replaced
  , ns        = window[config.namespace]
  , path      = ns.path
  , slash     = config.slash
  , domains   = config.domains
  , builtIns  = config.builtIns
  , arbiters  = []
  , stash     = {}
  , DomReg    = /^([\w]*)::/;

/**
 * Initialize stash with domain names and move data to it
 */
stash.M8 = {};
stash.external = {};
stash.data = ns.data;
delete ns.data;
stash.npm = {path : path};
delete ns.path;

domains.forEach(function (e) {
  stash[e] = {};
});

/**
 * Attach arbiters to the require system then delete them from the global scope
 */
Object.keys(config.arbiters).forEach(function (name) {
  var arbAry = config.arbiters[name];
  arbiters.push(name);
  stash.M8[name] = window[arbAry[0]];
  arbAry.forEach(function (e) {
    delete window[e];
  });
});

// same as server function
function isAbsolute(reqStr) {
  return reqStr === '' || path.normalize(reqStr) === reqStr;
}

function resolve(domains, reqStr) {
  reqStr = reqStr.split('.')[0];

  // direct folder require
  var skipFolder = false;
  if (reqStr.slice(-1) === slash || reqStr === '') {
    reqStr = path.join(reqStr, 'index');
    skipFolder = true;
  }

  if (config.logging >= 4) {
    console.debug('m8 scans : ' + JSON.stringify(domains) + ' for : ' + reqStr);
  }

  var dom, k, req;
  for (k = 0; k < domains.length; k += 1) {
    dom = domains[k];
    if (stash[dom][reqStr]) {
      return stash[dom][reqStr];
    }
    if (!skipFolder) {
      req = path.join(reqStr, 'index');
      if (stash[dom][req]) {
        return stash[dom][req];
      }
    }
  }

  if (config.logging >= 1) {
    console.error("m8: Unable to resolve require for: " + reqStr);
  }
}

/**
 * Require Factory for ns.define
 * Each (domain,path) gets a specialized require function from this
 */
function makeRequire(dom, pathName) {
  return function (reqStr) {
    if (config.logging >= 3) { // log verbatim pull-ins from dom::pathName
      console.log('m8: ' + dom + '::' + pathName + " <- " + reqStr);
    }

    if (!isAbsolute(reqStr)) {
      return resolve([dom], path.join(path.dirname(pathName), reqStr));
    }

    var domSpecific = DomReg.test(reqStr)
      , sDomain = false;

    if (domSpecific) {
      sDomain = reqStr.match(DomReg)[1];
      reqStr = reqStr.split('::')[1];
    }

    // require from/to npm domain - sandbox and join in current path if exists
    if (dom === 'npm' || (domSpecific && sDomain === 'npm')) {
      if (builtIns.indexOf(reqStr) >= 0) {
        return resolve(['npm'], reqStr);
      }
      if (domSpecific) {
        return resolve(['npm'], config.npmTree[reqStr].main);
      }
      // else, absolute: use included npmTree of mains
      // find root of module referenced in pathName, by counting number of node_modules referenced
      var order = pathName.split('node_modules').length;
      var root = pathName.split(slash).slice(0, Math.max(2 * (order - 2) + 1, 1)).join(slash);
      var branch = root.split(slash + 'node_modules' + slash).concat(reqStr);

      // use the branch array as the keys needed to traverse the npm tree
      var position = config.npmTree[branch[0]];
      for (var i = 1; i < branch.length; i += 1) {
        position = position.deps[branch[i]];
        if (!position) {
          // should not happen, remove eventually
          console.error('m8: expected vertex: ' + branch[i] + ' missing from current npm tree branch ' + pathName);
          return;
        }
      }
      return resolve(['npm'], position.main);
    }

    // domain specific
    if (domSpecific) {
      return resolve([sDomain], reqStr);
    }

    // general absolute, try arbiters
    if (arbiters.indexOf(reqStr) >= 0) {
      return resolve(['M8'], reqStr);
    }

    // general absolute, not an arbiter, try current domains, then the others
    return resolve([dom].concat(domains.filter(function (e) {
      return (e !== dom && e !== 'npm');
    })), reqStr);
  };
}

/**
 * define module name on domain container
 * expects wrapping fn(require, module, exports) { code };
 */
ns.define = function (name, domain, fn) {
  var mod = {exports : {}}
    , exp = {}
    , target;
  fn.call({}, makeRequire(domain, name), mod, exp);

  if (Object.prototype.toString.call(mod.exports) === '[object Object]') {
    target = (Object.keys(mod.exports).length) ? mod.exports : exp;
  }
  else {
    target = mod.exports;
  }
  stash[domain][name] = target;
};

/**
 * Public Debug API
 */

ns.inspect = function (domain) {
  console.log(stash[domain]);
};

ns.domains = function () {
  return domains.concat(['external', 'data']);
};

ns.require = makeRequire('app', 'CONSOLE');

/**
 * Live Extension API
 */

ns.data = function (name, exported) {
  if (stash.data[name]) {
    delete stash.data[name];
  }
  if (exported) {
    stash.data[name] = exported;
  }
};

ns.external = function (name, exported) {
  if (stash.external[name]) {
    delete stash.external[name];
  }
  if (exported) {
    stash.external[name] = exported;
  }
};
