var path          = require('path')
  , utils         = require('./utils')
  , join          = path.join
  , exists        = utils.exists
  , read          = utils.read
  , error         = utils.error
  , domainIgnores = /^data(?=::)|^external(?=::)|^M8(?=::)|^npm(?=::)/
  , domainPresent = /^([\w]*)::/;

// isAbsolute pass => reqStr and lies directly on the domain root
// isAbsolute fail => reqStr is relative to extraPath
function isAbsolute(reqStr) {
  return reqStr === '' || path.normalize(reqStr) === reqStr;
}

// Takes out domain prefix from a request string if exists
function stripDomain(reqStr) {
  var ary = reqStr.split('::');
  return ary[ary.length - 1];
}

/**
 * makeFinder
 *
 * finder factory for Resolver
 * @return finder function
 *
 * finder function scans join(base, req + ext) for closure held extensions
 */
function makeFinder(exts) {
  return function (base, req) {
    for (var i = 0; i < exts.length; i += 1) {
      var ext = exts[i]
        , attempt = join(base, req + ext);

      if (exists(attempt)) {
        return (req + ext);
      }
    }
    return false;
  };
}

/**
 * npmResolve factory
 *
 * creates a function which finds the entry point of an npm module
 * create with the node_modules root
 *
 * @[in] absReq - path node module should exist on
 * @[in] name   - name of the module for good error msgs
 * @[in] silent - bool === !(errors should throw)
 */
function makeNpmResolver(root) {
   return function (absReq, name, silent) {
    var folderPath = join(root, absReq)
      , jsonPath = join(folderPath, 'package.json')
      , json = {};

    console.log(folderPath);

    // folder must exists
    if (!path.existsSync(folderPath)) {
      if (!silent) {
        error("resolver could not resolve npm module " + name + " - path not found");
      }
      return false;
    }

    // package.json must exist
    if (!exists(jsonPath)) {
      if (!silent) {
        error("resolver could not load npm module " + name + " - package.json not found");
      }
      return false;
    }

    // package.json must be valid json
    try {
      json = JSON.parse(read(jsonPath));
    } catch (e) {
      if (!silent) {
        error("could not load npm module " + name + " - package.json invalid");
      }
      return false;
    }

    // prefer browserMain entry point if specified, then main, then index
    return json.browserMain || json.main || 'index';
  };
}

/**
 * toAbsPath
 *
 * converts a generic detective request string to an absolute one
 * throws if it receives an obviously bad request
 *
 * @[in] reqStr - raw request string
 * @[in] extraPath - path of requiree's relative position to domain root
 * @[in] domain
 */
// absolutizes a path - special cases the npm domain
function toAbsPath(reqStr, extraPath, domain) {
  if (domainPresent.test(reqStr)) {
    domain = reqStr.match(domainPresent)[1]; // override current domain if explicitly specified
    if (!isAbsolute(reqStr)) {
      error("does not allow cross-domain relative requires (" + reqStr + ")");
    }
    return [stripDomain(reqStr), domain];
  }
  else if (isAbsolute(reqStr)) {
    if (domain === 'npm') { // sandbox npm domain
      if (reqStr === 'path' || reqStr === 'util' || reqStr === 'sys' || reqStr === 'fs') {
        error("cannot require server side node module " + reqStr);
      }
      return [join(extraPath, 'node_modules', reqStr), 'npm'];
    }
    else {
      return [reqStr, null];
    }
  }
  else {
    return [join(extraPath, reqStr), domain];
  }
}

/**
 * Resolver constructor
 * @[in] domains - {name : path} object
 * @[in] arbiters - list of requirable arbiters
 * @[in] exts - list of registered extensions
 */
function Resolver(domains, arbiters, exts) {
  this.finder = makeFinder(exts);
  this.npmResolve = makeNpmResolver(domains.npm)
  this.domains = domains;
  this.arbiters = arbiters;
  this.exts = exts;
}

/**
 * scan [private]
 * scans a set of domain names for absReq
 *
 * @[in] absReq - require string relative to a domain root
 * @[in] scannable - ordered list of domain names to scan
 * @return === locate's return if found, else false
 **/
Resolver.prototype.scan = function (absReq, scannable) {
  var noTryFolder = false
    , lastChar = absReq.slice(-1);

  if (lastChar === '/' || lastChar === '\\') {
    absReq = join(absReq, 'index');
    noTryFolder = true;
  }
  for (var i = 0; i < scannable.length; i += 1) {
    var dom = scannable[i]
      , found = this.finder(this.domains[dom], absReq);

    if (found) {
      return [found, dom, true];
    }

    if (noTryFolder) {
      continue;
    }

    found = this.finder(this.domains[dom], join(absReq, 'index'));
    if (found) {
      return [found, dom, true];
    }
  }
  return false;
};

/**
 * locate
 *
 * locates a required file - throws on bad requests - main interface
 *
 * @[in] reqStr from detective
 * @[in] path of requiree's relative position to domain root
 * @[in] requiree's domain
 * @return [foundPath, domainName, isFake] where:
 *
 * [str] foundPath  - full path of the chosen file to use
 * [str] domainName - name of the domain it was found on
 * [bool] isReal    - true iff foundPath represents a real file
 **/
Resolver.prototype.locate = function (reqStr, currentPath, currentDomain) {
  var absResult = toAbsPath(reqStr, currentPath, currentDomain)
    , absReq = absResult[0]
    , foundDomain = absResult[1]
    , npmMain = false
    , found = false
    , result = false
    , msg = '';

  console.log("resolve: ", reqStr, currentDomain, "found: ", foundDomain, absReq);
  if (domainIgnores.test(reqStr)) {
    if (foundDomain === 'data' || foundDomain === 'external') {
      return [absReq, foundDomain, false];
    }
    if (foundDomain === 'M8') {
      if (this.arbiters.indexOf(absReq) >= 0) {
        return [absReq, 'M8', false];
      }
      error("resolver could not require non-existent arbiter: " + reqStr + " (from " + currentDomain + ")");
    }
    if (foundDomain === 'npm') {
      if (!this.domains.npm) {
        error("resolver cannot require from npm module without specifying the node_modules root")
      }
      npmMain = this.npmResolve(absReq, reqStr, false); // explicitly specified npm:: => throw on errors
      found = this.finder(npmMain, '');
      if (found) {
        return [found, 'npm', true];
      }
      error("resolver could not require invalid npm module with lying package.json: " + reqStr);
    }
  }
  else {
    if (foundDomain && !this.domains[foundDomain]) { // also prevents second call to npmResolve
      error("resolver could not require from an unconfigured domain: " + foundDomain);
    }
    if (foundDomain === 'app' && currentDomain !== 'app') {
      error("does not allow other domains to reference the app domain. required from " + currentDomain);
    }

    npmMain = this.npmResolve(absReq, reqStr, true);
    console.log("in here, npmmain:", npmMain);
    if (foundDomain === 'npm' && !npmMain) { // sandbox npm domain => throw if failure to require within
      error("can not implicitly require an npm module without a package.json " + reqStr);
    }

    if (foundDomain) { // require to a specific/same domain - we must succeed in here
      result = this.scan(absReq, [foundDomain]);
      if (result) {
        return result;
      }
      msg = " for extensions " + this.exts.slice(1).join(', ');
      error("resolver failed to resolve require('" + reqStr + "') in " + foundDomain + msg);
    }

    // do arbiters before global npm tests
    if (this.arbiters.indexOf(absReq) >= 0) {
      return [absReq, 'M8', false];
    }

    // global npm tests
    if (foundDomain === null && npmMain) {
      found = this.finder(npmMain, '');
      if (found) {
        return [found, 'npm', true];
      }
      error("could not require invalid npm module with lying package.json: " + reqStr);
    }

    // anything else - check currentDomain then all other standard ones for absReq
    var scannable = Object.keys(this.domains).filter(function (d) {
      return (d !== currentDomain);
    });
    scannable.unshift(currentDomain);

    result = this.scan(absReq, scannable);
    if (result) {
      return result;
    }
    msg = " - looked in " + scannable + " for extensions " + this.exts.slice(1).join(', ');
    error("resolver failed to resolve require('" + reqStr + "') from " + currentDomain + msg);
  }
};

module.exports = function (domains, arbiters, exts) {
  var r = new Resolver(domains, arbiters, exts);
  return function () {
    return r.locate.apply(r, arguments);
  };
};
