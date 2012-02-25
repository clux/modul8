var fs        = require('fs')
  , path      = require('path')
  , deputy    = require('deputy')
  , utils     = require('./utils')
  , resolver  = require('./resolver')
  , topiary   = require('topiary')
  , error     = utils.error
  , join      = path.join;


/**
 * Analyzer class
 *
 */
function Analyzer(obj, before, compile, builtIns, serverModules) {
  this.entryPoint = obj.entryPoint;
  this.domains = obj.domains;
  this.ignoreDoms = obj.ignoreDoms;
  this.deputy = deputy(join(__dirname, '..', 'deputy.json'));
  this.before = before;
  this.compile = compile;
  this.npmTree = {
    _builtIns : []
  }; // resolver builds this - makes sanitizing our tree easier as well
  this.resolve = resolver(this.domains, Object.keys(obj.arbiters), obj.exts, this.npmTree, builtIns, serverModules);
  //TODO: need builtIns / serverModules for analysis purposes?
  this.buildTree();
}

/**
 * dependencies
 *
 * Resolves all the dependencies of a file through detective
 *
 * @[in] absReq - absolute path to file
 * @[in] extraPath - path relative to domain path
 * @[in] dom - name of the domain extraPath is relative to
 * @return Array of resolver output
 * i.e. triples of form: [absPath, domain, isReal]
 */
Analyzer.prototype.dependencies = function (absReq, extraPath, dom) {
  // get 'before' sanitized code
  var code = this.before(this.compile(join(this.domains[dom], absReq)))
    , resolve = this.resolve;

  // absolutizes and locates everything immediately so that
  // we have a unique representation of each file

  // detective scanning each file is the most time consuming process on big codebases so we use the deputy caching layer
  //console.log('scanning', absReq)
  return this.deputy(code).map(function (req) {
    return resolve(req, extraPath, dom);
  });
};

/**
 * buildTree
 *
 * Calls this.dependencies recursively from the entry point
 * Stores this.tree in instance of form:
 * {
 *    name      : domain relative fileName
 *    domain    : domain name with entry in this.domains
 *    extraPath : dirname of name
 *    isReal    : if true then join(this.domais[domainName], fileName) exists
 *    deps      : object of {uid : recursive this for each file}
 *    parent    : refers to parent structure one up from deps [root does not have this]
 *    level     : number of levels in (in terms of deps) we are [0 indexed]
  * }
 */
Analyzer.prototype.buildTree = function () {
  this.tree = {
    name      : this.entryPoint
  , domain    : 'app'
  , extraPath : ''
  , deps      : {}
  , fake      : 0
  , level     : 0
  };

  var circularCheck = function (t, uid) {
    var chain = [uid];
    while (true) { // follow the branch up to verify we do not find self
      if (!t.parent) {
        return;
      }
      chain.push(t.domain + '::' + t.name);
      t = t.parent;
      if (chain[chain.length - 1] === chain[0]) {
        error("analysis revealed a circular dependency: " + chain.join(' <- '));
      }
    }
  };

  var build = function (t) {
    var resolveRes = this.dependencies(t.name, t.extraPath, t.domain);
    //console.log("resolved: ", JSON.stringify(resolveRes));

    for (var i = 0; i < resolveRes.length; i += 1) {
      var triple = resolveRes[i]
        , name = triple[0]
        , domain = triple[1]
        , isReal = triple[2]
        , uid = domain + '::' + name;

      t.deps[uid] = {
        name      : name
      , domain    : domain
      , isReal    : isReal
      , extraPath : path.dirname(name)
      , deps      : {}
      , parent    : t
      , level     : t.level + 1
      };
      if (isReal) {
        circularCheck(t, uid);          // throw on circulars
        build.call(this, t.deps[uid]);  // recurse
      }
    }
  };
  build.call(this, this.tree);
};

// print format helper
function makeFormatter(extSuffix, domPrefix) {
  return function (ele) {
    var n = extSuffix ? ele.name : ele.name.split('.')[0];
    if (ele.domain === 'npm') {
      n = path.basename(n); //TODO: improve this
    }
    else if (n.indexOf('index') >= 0 && path.basename(n) === n) {
      n = ''; // take out domain index requires to make print more readable
    }
    if (domPrefix) {
      n = ele.domain + '::' + n;
    }
    return n;
  };
}

/**
 * print
 * constructs a prettified dependency tree
 *
 * @[in] extSuffix - true iff show extensions everywhere
 * @[in] domPrefix - true iff show domain prefixes everywhere
 * @return printable string
 */
Analyzer.prototype.print = function (extSuffix, domPrefix) {
  var ignores = this.ignoreDoms;
  var shapeFn = makeFormatter(extSuffix, domPrefix);
  var filterFn = function (el) {
    return (ignores.indexOf(el.domain) < 0);
  };
  return topiary(this.tree, 'deps', shapeFn, filterFn);
};

/**
 * sort
 * sorts the dependency tree by maximum require level descending
 *
 * @return Array of pairs [domain, name] where join(domain, name) exists
 */
Analyzer.prototype.sort = function () {
  var obj = {};
  obj['app::' + this.entryPoint] = 0;

  var sort = function (t) {
    Object.keys(t.deps).forEach(function (uid) {
      var dep = t.deps[uid];
      if (!dep.isReal) {
        return;
      }
      obj[uid] = Math.max(dep.level, obj[uid] || 0);
      sort(dep); // recurse
    });
  };
  sort(this.tree);

  return Object.keys(obj).map(function (uid) {
    return [uid, obj[uid]];   // convert obj to sortable array of [uid, level] pairs
  }).sort(function (a, b) {
    return b[1] - a[1];       // sort by level descending to get correct insertion order
  }).map(function (e) {
    return e[0].split('::');  // map to pairs of form [domain, name]
  });
};


module.exports = function (obj, before, compile, builtIns, serverModules) {
  var o = new Analyzer(obj, before, compile, builtIns, serverModules);
  return {
    print: function () {
      return o.print.apply(o, arguments);
    }
  , sort: function () {
      return o.sort.apply(o, arguments);
    }
  , npm: function () {
      //console.log(JSON.stringify(o.npmTree));
      return o.npmTree;
    }
  };
};

