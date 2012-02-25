var path          = require('path')
  , utils         = require('./utils')
  , join          = path.join
  , exists        = utils.exists
  , read          = utils.read
  , error         = utils.error
  , domainIgnoreR = /^data(?=::)|^external(?=::)|^M8(?=::)|^npm(?=::)/
  , domainIgnoreL = ['data', 'external', 'M8', 'npm']
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
 * @[in] silent - bool === !(errors should throw)
 * @[in] name   - name of the module for good error msgs
 */
function makeNpmResolver(root) {
  return function (absReq, name) {
    var folderPath = join(root, absReq)
      , jsonPath = join(folderPath, 'package.json')
      , json = {};

    // folder must exists if we commit to it
    if (!path.existsSync(folderPath)) {
      return false;
    }

    // package.json must exist
    if (!exists(jsonPath)) {
      error("resolver could not load npm module " + name + " - package.json not found");
      return false;
    }

    // package.json must be valid json
    try {
      json = JSON.parse(read(jsonPath));
    } catch (e) {
      error("could not load npm module " + name + " - package.json invalid");
    }

    // prefer browserMain entry point if specified, then main, then index
    var mainFile = json.browserMain || json.main || 'index';
    if (!exists(join(folderPath, mainFile))) {
      if (!exists(join(folderPath, mainFile + '.js'))) {
        error("resolver could not load npm module " + name + "'s package.json lies about main: " + mainFile + " does not exist");
      }
      mainFile += '.js';
    }
    return join(absReq, mainFile);
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
    // special case absolutes from npm domain
    // this sandboxes the npm domain (sensible)
    if (domain === 'npm') {
      return [reqStr, 'npm']; // explicit npms need to be handled elsewhere
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
function Resolver(domains, arbiters, exts, npmTree, builtIns, serverModules) {
  this.finder = makeFinder(exts);
  this.npmResolve = makeNpmResolver(domains.npm);
  this.domains = domains;
  this.arbiters = arbiters;
  this.exts = exts;
  this.npmTree = npmTree;
  this.builtIns = builtIns;
  this.serverModules = serverModules;
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
    , found = false
    , result = false
    , that = this
    , msg = '';

  if (domainIgnoreL.indexOf(foundDomain) >= 0) {

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
      var name = absReq; // at this point, this is safe

      // node module priority:
      // 1. if we are requiring a builtin (sanitized) server-side module - return that
      // 2a.  if required from root, do
      // 2b1. try to locate node module in node_module subfolder of current node module
      // 2b2. look up one level in the tree recursively until a hit is found || we hit the domain root
      // 4. throw


      // 1. builtins
      if (this.builtIns.indexOf(name) >= 0) {
        if (this.npmTree._builtIns.indexOf(name) < 0) {
          this.npmTree._builtIns.push(name);
        }
        return [name, 'npm', false]; // this should be fine, should really be on the npm namespace
      }
      // 1. unhandled node base modules
      else if (this.serverModules.indexOf(name) >= 0) {
        error("cannot require server side node module " + name);
      }

      // catch illegal use if not builtIn (they do not require a node_modules root)
      if (!this.domains.npm) {
        error("resolver cannot require non-builtin node modules without specifying the node_modules root. tried " + name);
      }

      var npmMain;

      // 2a. entry point branch to npm domain
      if (currentDomain !== 'npm') {
        npmMain = this.npmResolve(name, name);
        if (npmMain) {
          this.npmTree[name] = {
            main : npmMain
          , deps : {}
          };
          return [npmMain, 'npm', true];
        }
        error('could not find module', reqStr);
      }


      // 2b. try current + node_modules + the string specified
      // but first make sure we start at the module's root before we join on node_modules
      var slash = '/'; // TODO..
      var order = currentPath.split('node_modules').length;
      var moduleRoot = currentPath.split(slash).slice(0, Math.max(2 * (order - 2) + 1, 1)).join(slash);

      var expected = join(moduleRoot, 'node_modules', name);
      var branch = moduleRoot.split(slash + 'node_modules' + slash);

      npmMain = this.npmResolve(expected, name);
      if (npmMain) {
        var position = this.npmTree[branch[0]];
        for (var i = 1; i < branch.length; i += 1) {
          position = position.deps[branch[i]];
          if (!position) {
            error('internal resolver error 1');
            // if this happens then we are not able to walk up to requiree's point
            // recursive solving => this should be impossible
          }
        }
        position.deps[name] = {
          main : npmMain
        , deps : {}
        };
        return [npmMain, 'npm', true];
      }

      // 2b2.
      var oldBranch = branch;
      while (true) {
        expected = join(expected, '..', '..', '..', name);
        if (expected === '.' || expected.slice(0, 2) === '..') { // broken out of domain root
          break;
        }
        branch = branch.slice(0, -1); // we went one up

        npmMain = this.npmResolve(expected, name);
        if (npmMain) {
          // need to give a link to this module regardless of where in the hierarchy it is
          var oldPos = this.npmTree[oldBranch[0]];
          for (var j = 1; j < oldBranch.length; j += 1) {
            oldPos = oldPos.deps[oldBranch[j]];
            if (!oldPos) {
              error('internal resolver error 3');
              // if this happens then we are not able to walk up to the point we have
              // already filled in. recursive solving => this should be impossible
            }
          }
          oldPos.deps[name] = {
            main : npmMain
          , deps : {}
          };

          // now make it requirable to everything above
          if (!branch.length) {
            // structure of the tree is different at base for historical reasons
            this.npmTree[name] = {
              main : npmMain
            , deps : {}
            };
            return [npmMain, 'npm', true];
          }
          var pos = this.npmTree[branch[0]];
          for (var k = 1; k < branch.length; k += 1) {
            pos = pos.deps[branch[k]];
            if (!pos) {
              error('internal resolver error 2');
              // if this happens then we are not able to walk _partially_ up towards
              // a point we have defined. recursive solving => this should be impossible
            }
          }
          pos.deps[name] = {
            main : npmMain
          , deps : {}
          };
          return [npmMain, 'npm', true];
        }
      }

      // 4. nothing worked
      error("failed to require npm module " + name);

    }
  }
  else { // anything that was absolutely required from outside npm
    if (foundDomain && !this.domains[foundDomain]) { // also prevents second call to npmResolve
      error("resolver could not require from an unconfigured domain: " + foundDomain);
    }
    if (foundDomain === 'app' && currentDomain !== 'app') {
      error("does not allow other domains to reference the app domain. required from " + currentDomain);
    }

    if (foundDomain) { // require to a specific/same domain - we must succeed in here
      result = this.scan(absReq, [foundDomain]);
      if (result) {
        return result;
      }
      msg = " for extensions [" + this.exts.slice(1).join(', ') + "]";
      error("resolver failed to resolve require('" + reqStr + "') in " + foundDomain + msg);
    }

    // absolute requires from app domain cannot indirectly require npm modules for safety
    // but this behaviour needs to work inside the npm domain, so toAbsPath sandboxes it meaning we never get

    // arbiters check - safe to do globally as arbiters were specified explicitly
    if (this.arbiters.indexOf(absReq) >= 0) {
      return [absReq, 'M8', false];
    }

    // anything else - check currentDomain then all other standard ones for absReq
    var scannable = Object.keys(this.domains).filter(function (d) {
      return (d !== currentDomain && d !== 'npm');
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

module.exports = function (domains, arbiters, exts, npmTree, builtIns, serverModules) {
  var r = new Resolver(domains, arbiters, exts, npmTree, builtIns, serverModules);
  return function () {
    return r.locate.apply(r, arguments);
  };
};
