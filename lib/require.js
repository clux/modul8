
/**
 * modul8 v__VERSION__
 */

var config    = __REQUIRECONFIG__
  , ns        = window[config.namespace]
  , domains   = config.domains
  , arbiters  = []
  , exports   = {}
  , DomReg    = /^(.*)::/;

/**
 * Initialize the exports container with domain names + move data to it
 */
for (var i = 0; i < domains.length; i++)
  exports[domains[i]] = {};

exports.M8 = {};
exports.external = {};
exports.data = ns.data;
delete ns.data;

/**
 * Attach arbiters to the require system then delete them from the global scope
 */
for (var name in config.arbiters) {
  var arry  = config.arbiters[name]
    , temp = window[name];
  arbiters.push(name);
  for (var j = 0; j < arry.length; j++) delete window[arry[j]];
  exports.M8[name] = temp;
}

/**
 * Converts a relative path to an absolute one
 */
function toAbsPath(pathName, relReqStr) {
  var folders = pathName.split('/').slice(0, -1);
  while (relReqStr.slice(0, 3) === '../') {
    folders = folders.slice(0, -1);
    relReqStr = relReqStr.slice(3);
  }
  return folders.concat(relReqStr.split('/')).join('/');
};

/**
 * Require Factory for ns.define
 * Each (domain,path) gets a specialized require function from this
 */
function makeRequire(dom, pathName) {
  return function(reqStr) {
    var o, scannable, k;

    if (config.logging >= 4)
      console.debug('modul8: '+dom+':'+pathName+" <- "+reqStr);

    if (reqStr.slice(0, 2) === './') {
      scannable = [dom];
      reqStr = toAbsPath(pathName, reqStr.slice(2));
    } else if (reqStr.slice(0,3) === '../') {
      scannable = [dom];
      reqStr = toAbsPath(pathName, reqStr)
    } else if (DomReg.test(reqStr)) {
      scannable = [reqStr.match(DomReg)[1]];
      reqStr = reqStr.split('::')[1];
    } else if (arbiters.indexOf(reqStr) >= 0) {
      scannable = ['M8'];
    } else {
      scannable = [dom].concat(domains.filter(function(e) {return e !== dom;}));
    }
    reqStr = reqStr.split('.')[0];
    if (reqStr.slice(-1) === '/') {
      reqStr += 'index';
      var skipFolder = true;
    }

    if (config.logging >= 3)
      console.log('modul8: '+dom+':'+pathName+" <- "+reqStr);
    if (config.logging >= 4)
      console.debug('modul8: scanned '+JSON.stringify(scannable))

    for (k = 0; k < scannable.length; k++) {
      o = scannable[k];
      if (exports[o][reqStr])
        return exports[o][reqStr];

      if (!skipFolder && exports[o][reqStr + '/index'])
        return exports[o][reqStr + '/index'];
    }

    if (config.logging >= 1)
      console.error("modul8: Unable to resolve require for: " + reqStr);
  };
};

ns.define = function(name, domain, fn) {
  var module = {};
  fn(makeRequire(domain, name), module, exports[domain][name] = {});
  if (module.exports) {
    delete exports[domain][name];
    exports[domain][name] = module.exports;
  }
};

/**
 * Public Debug API
 */

ns.inspect = function(domain) {
  console.log(exports[domain]);
};

ns.domains = function() {
  return domains.concat(['external']);
};

ns.require = makeRequire('app', 'CONSOLE');

/**
 * Live Extension API
 */

exports.M8.data = ns.data = function(name, exported) {
  if (exports.data[name]) delete exports.data[name];
  if (exported) exports.data[name] = exported;
};

exports.M8.external = ns.external = function(name, exported) {
  if (exports.external[name]) delete exports.exernal[name];
  if (exported) exports.extenal[name] = exported;
};