(function(){
window.QQ = {data:{}, path:{}};

// include npm::path
(function (exports) {
 function filter (xs, fn) {
    var res = [];
    for (var i = 0; i < xs.length; i++) {
        if (fn(xs[i], i, xs)) res.push(xs[i]);
    }
    return res;
}

// resolves . and .. elements in a path array with directory names there
// must be no slashes, empty elements, or device names (c:\) in the array
// (so also no leading and trailing slashes - it does not distinguish
// relative and absolute paths)
function normalizeArray(parts, allowAboveRoot) {
  // if the path tries to go above the root, `up` ends up > 0
  var up = 0;
  for (var i = parts.length; i >= 0; i--) {
    var last = parts[i];
    if (last == '.') {
      parts.splice(i, 1);
    } else if (last === '..') {
      parts.splice(i, 1);
      up++;
    } else if (up) {
      parts.splice(i, 1);
      up--;
    }
  }

  // if the path is allowed to go above the root, restore leading ..s
  if (allowAboveRoot) {
    for (; up--; up) {
      parts.unshift('..');
    }
  }

  return parts;
}

// Regex to split a filename into [*, dir, basename, ext]
// posix version
var splitPathRe = /^(.+\/(?!$)|\/)?((?:.+?)?(\.[^.]*)?)$/;

// path.resolve([from ...], to)
// posix version
exports.resolve = function() {
var resolvedPath = '',
    resolvedAbsolute = false;

for (var i = arguments.length; i >= -1 && !resolvedAbsolute; i--) {
  var path = (i >= 0)
      ? arguments[i]
      : process.cwd();

  // Skip empty and invalid entries
  if (typeof path !== 'string' || !path) {
    continue;
  }

  resolvedPath = path + '/' + resolvedPath;
  resolvedAbsolute = path.charAt(0) === '/';
}

// At this point the path should be resolved to a full absolute path, but
// handle relative paths to be safe (might happen when process.cwd() fails)

// Normalize the path
resolvedPath = normalizeArray(filter(resolvedPath.split('/'), function(p) {
    return !!p;
  }), !resolvedAbsolute).join('/');

  return ((resolvedAbsolute ? '/' : '') + resolvedPath) || '.';
};

// path.normalize(path)
// posix version
exports.normalize = function(path) {
var isAbsolute = path.charAt(0) === '/',
    trailingSlash = path.slice(-1) === '/';

// Normalize the path
path = normalizeArray(filter(path.split('/'), function(p) {
    return !!p;
  }), !isAbsolute).join('/');

  if (!path && !isAbsolute) {
    path = '.';
  }
  if (path && trailingSlash) {
    path += '/';
  }

  return (isAbsolute ? '/' : '') + path;
};


// posix version
exports.join = function() {
  var paths = Array.prototype.slice.call(arguments, 0);
  return exports.normalize(filter(paths, function(p, index) {
    return p && typeof p === 'string';
  }).join('/'));
};


exports.dirname = function(path) {
  var dir = splitPathRe.exec(path)[1] || '';
  var isWindows = false;
  if (!dir) {
    // No dirname
    return '.';
  } else if (dir.length === 1 ||
      (isWindows && dir.length <= 3 && dir.charAt(1) === ':')) {
    // It is just a slash or a drive letter with a slash
    return dir;
  } else {
    // It is a full dirname, strip trailing slash
    return dir.substring(0, dir.length - 1);
  }
};


exports.basename = function(path, ext) {
  var f = splitPathRe.exec(path)[2] || '';
  // TODO: make this comparison case-insensitive on windows?
  if (ext && f.substr(-1 * ext.length) === ext) {
    f = f.substr(0, f.length - ext.length);
  }
  return f;
};


exports.extname = function(path) {
  return splitPathRe.exec(path)[3] || '';
};

}(window.QQ.path));
QQ.data.test = {"hi": "there"}
;
(function(){
/**
 * modul8 v0.15.1
 */

var config    = {"namespace":"QQ","domains":["app","shared"],"arbiters":{"monolith":["monolith"]},"npmTree":{},"builtIns":["path","events"],"slash":"/"} // replaced
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
  reqStr = reqStr.split('.')[0]; // remove extension

  // direct folder require
  var skipFolder = false;
  if (reqStr.slice(-1) === slash || reqStr === '') {
    reqStr = path.join(reqStr, 'index');
    skipFolder = true;
  }

  if (config.logging >= 4) {
    console.debug('modul8 looks in : ' + JSON.stringify(domains) + ' for : ' + reqStr);
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
    console.error("modul8: Unable to resolve require for: " + reqStr);
  }
}

/**
 * Require Factory for ns.define
 * Each (domain,path) gets a specialized require function from this
 */
function makeRequire(dom, pathName) {
  return function (reqStr) {
    if (config.logging >= 3) { // log verbatim pull-ins from dom::pathName
      console.log('modul8: ' + dom + '::' + pathName + " <- " + reqStr);
    }

    if (!isAbsolute(reqStr)) {
      //console.log('relative resolve:', reqStr, 'from domain:', dom, 'join:', path.join(path.dirname(pathName), reqStr));
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
        return resolve(['npm'], reqStr); // => can put builtIns on npm::
      }
      if (domSpecific) {
        return resolve(['npm'], config.npmTree[reqStr].main);
      }
      // else, absolute: use included hashmap tree of npm mains

      // find root of module referenced in pathName, by counting number of node_modules referenced
      // this ensures our startpoint, when split around /node_modules/ is an array of modules requiring each other
      var order = pathName.split('node_modules').length; //TODO: depending on whether multiple slash types can coexist, conditionally split this based on found slash type
      var root = pathName.split(slash).slice(0, Math.max(2 * (order - 2) + 1, 1)).join(slash);

      // server side resolver has figured out where the module resides and its main
      // use resolvers passed down npmTree to get correct require string
      var branch = root.split(slash + 'node_modules' + slash).concat(reqStr);
      //console.log(root, order, reqStr, pathName, branch);
      // use the branch array to find the keys used to traverse the npm tree, to find the key of this particular npm module's main in stash
      var position = config.npmTree[branch[0]];
      for (var i = 1; i < branch.length; i += 1) {
        position = position.deps[branch[i]];
        if (!position) {
          console.error('expected vertex: ' + branch[i] + ' missing from current npm tree branch ' + pathName); // should not happen, remove eventually
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

}());

// shared code

QQ.define('calc','shared',function (require, module, exports) {

module.exports = {
  divides: function(d, n) {
    return !(d % n);
  }
};

});
QQ.define('validation','shared',function (require, module, exports) {
var divides;

divides = require('./calc').divides;

exports.isLeapYear = function(yr) {
  return divides(yr, 4) && (!divides(yr, 100) || divides(yr, 400));
};

});

// app code - safety wrapped


QQ.define('bigthing/sub2','app',function (require, module, exports) {

module.exports = function(str) {
  return console.log(str);
};

});
QQ.define('helper','app',function (require, module, exports) {
var testRunner;

module.exports = function(str) {
  return console.log(str);
};

});
QQ.define('bigthing/sub1','app',function (require, module, exports) {
var sub2;

sub2 = require('./sub2');

exports.doComplex = function(str) {
  return sub2(str + ' (sub1 added this, passing to sub2)');
};

});
QQ.define('main','app',function (require, module, exports) {
var b, helper, m, test, v;

helper = require('./helper');

helper('hello from app via helper');

b = require('bigthing/sub1');

b.doComplex('app calls up to sub1');

v = require('validation.coffee');

console.log('2004 isLeapYear?', v.isLeapYear(2004));

m = require('monolith');

console.log("monolith:" + m);

test = require('data::test');

console.log('injected data:', test);

});
}());