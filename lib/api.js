var fs          = require('fs')
  , path        = require('path')
  , bundle      = require('./bundle.coffee')
  , type        = require('./type')
  , logule      = require('logule').sub('modul8')
  , utils       = require('./utils')
  , exists      = utils.exists
  , error       = utils.error
  , environment = process.env.NODE_ENV || 'development'
  , envCurrent  = 'all'
  , o           = {};

var logLevels = {
  error : 1
, warn  : 2
, info  : 3
, debug : 4
};

var reserved = {
  'app'       : 'the main code where the entry point resides'
, 'data'      : 'injected data'
, 'external'  : 'externally loaded code'
, 'M8'        : 'the internal debug API'
, 'npm'       : 'node mdules'
};

/**
 * Base class
 */
function Base(sub) {
  var subName = (sub) ? sub : 'None'; //TODO.ES6 name object

  this.subclassMatches = function (subclass, method) {
    if (subName !== subclass) {
      (o.logger || logule).warn("Ignoring an invalid call to " + subclass + "::" + method + " after having broken out from the " + subclass + " subclass");
      return false;
    }
    return true;
  };

  this.removeSubClassMethods = function () {
    subName = 'None';
  };
}

// Helper for Base.prototype.in
function envCheck() {
  return (environment === envCurrent || envCurrent === 'all');
}

/**
 * Module Start
 * API starts by filling in the static options object
 * Then returning the chainable Base class instance
 */
module.exports = function (entry) {
  var dom = path.dirname(path.resolve(entry))
    , file = path.basename(entry);

  if (!exists(path.join(dom, file))) {
    error("cannot find entry file: " + path.join(dom, file));
  }
  o = {
    data        : {}
  , arbiters    : {}
  , domains     : {
      'app'       : dom
    }
  , pre         : []
  , post        : []
  , ignoreDoms  : []
  , compilers   : {}
  , entryPoint  : file
  , options     : {
      namespace   : 'M8'
    , domloader   : ''
    , logging     : 'ERROR'
    , force       : false
    , persist     : path.join(__dirname, '..', 'state.json')
    }
  };
  return new Base();
};

/**
 * in(env)
 * Do the next chained calls only if we are in env
 * Lasts until in('all') is called
 */
Base.prototype.in = function (env) {
  envCurrent = env;
  return this;
};

/**
 * logger
 * Any subsequent work will use the configured logule sub if called
 */
Base.prototype.logger = function (sub) {
  this.removeSubClassMethods();
  if (envCheck()) {
    if (!logule.verify(sub)) {
      error("got an invalid logule instance sent to logger - out of date?");
    }
    // if a sub is passed in, it is assumed to be filtered outside this anyway
    o.logger = sub;
  }
  return this;
};

/**
 * before
 * Can be (repeat) called with a function or list of functions that will executed on the code before analysis
 * Good for internal test dependencies
 */
Base.prototype.before = function (fn) {
  this.removeSubClassMethods();
  if (envCheck()) {
    if (type.isArray(fn)) {
      var that = this;
      fn.forEach(function (f) {
        that.before(f);
      });
    }
    else if (!type.isFunction(fn)) {
      (o.logger || logule).warn("require 'before' functions to actually be functions - got " + fn);
    }
    else {
      o.pre.push(fn);
    }
  }
  return this;
};

/**
 * after
 * Can be (repeat) called with a function or list of functions that will be executed on the code at compiliation time
 * Good for custom minification
 */
Base.prototype.after = function (fn) {
  this.removeSubClassMethods();
  if (envCheck()) {
    if (type.isArray(fn)) {
      var that = this;
      fn.forEach(function (f) {
        that.after(f);
      });
    }
    else if (!type.isFunction(fn)) {
      (o.logger || logule).warn("require 'after' functions to actually be functions - got " + fn);
    }
    else {
      o.post.push(fn);
    }
  }
  return this;
};

// use helper
function addPlugin(inst){
  var name = inst.name
    , data = inst.data
    , dom = inst.domain;

  if (!name) {
    error('plugin has an bad/undefined name key');
  }

  if (type.isFunction(data)) {
    var dataval = data();
    if (!dataval) {
      error('plugin ' + name + 'returned bad value from its defined data method');
    }
    (new Data()).add(name, dataval);
  }

  if (type.isFunction(dom)) {
    var domval = dom();
    if (!domval) {
      error('plugin "' + name + '" returned bad value from its defined domain method');
    }
    (new Domains()).add(name, dom);
  }
}

/**
 * use
 * Call with a Plugin instance (or list of) to pull in bundled data &&|| code from a domain
 */
Base.prototype.use = function (inst) {
  this.removeSubClassMethods();
  if (envCheck()) {
    var that = this;

    if (type.isArray(inst)) {
      inst.forEach(function (plugin) {
        addPlugin(plugin);
      });
    }
    else {
      addPlugin(inst);
    }
  }
  return this;
};

/**
 * register
 * Call with an extension and a compiler to register compile-to-JS languages
 */
Base.prototype.register = function (ext, compiler) {
  this.removeSubClassMethods();
  if (envCheck()) {
    if (ext === '' || ext === '.js') {
      error("cannot re-register the " + (ext === '' ? 'blank' : ext) + " extension");
    }
    if (!type.isFunction(compiler)) {
      error("registered compilers must be a function returning a string - " + ext + " extension failed");
    }
    o.compilers[ext] = compiler;
  }
  return this;
};

/**
 * npm
 * Call with a path to a node_modules folder to enable requiring of browser compatible npm modules
 */
Base.prototype.npm = function (dir) {
  this.removeSubClassMethods();
  if (envCheck()) {
    o.domains.npm = path.resolve(dir);
    if (!path.existsSync(o.domains.npm)) {
      error('could not resolve the npm path - ' + o.domains.npm + ' does not exist');
    }
  }
  return this;
};

/**
 * set
 * Set one of the valid options
 */
Base.prototype.set = function (key, val) {
  this.removeSubClassMethods();
  if (envCheck()) {
    if (Object.keys(o.options).indexOf(key) >= 0) {

      if (key === 'namespace') {
        if (!type.isString(val) || val === '') {
          error("cannot use a non-string or blank namespace");
        }
        if (!/^[\w_$]*$/.test(val) || !/^[A-Za-z_$]/.test(val)) {
          error("require a namespace valid as a variable name, got " + val);
        }
      }
      else if (key === 'persist') {
        if (!exists(val)) {
          error("got an invalid persist file: " + val);
        }
      }
      else if (key === 'logging') {
        o.logLevel = logLevels[(val + '').toLowerCase()] || 0;
        if (o.logLevel < 4) {
          (o.logger || logule).suppress('debug');
        }
        if (o.logLevel < 2) {
          (o.logger || logule).suppress('warn', 'info');
        }
      }
      else if (key === 'domloader') {
        if (!type.isString(val) && !type.isFunction(val)) {
          error("got an invalid domloader options - must be string of function");
        }
      }

      o.options[key] = val;
    }
  }
  return this;
};


/**
 * Data subclass
 */
function Data() {}
Data.prototype = new Base('Data');

/**
 * Entry point for Data subclass
 */
Base.prototype.data = function (input) {
  this.removeSubClassMethods();
  var dt = new Data();
  if (envCheck()) {
    if (type.isObject(input)) {
      Object.keys(input).forEach(function (key) {
        dt.add(key, input[key]);
      });
    }
  }
  return dt;
};

/**
 * Data subclass methods
 */
Data.prototype.add = function (key, val) {
  if (this.subclassMatches('Data', 'add') && envCheck()) {
    if (key && val) {
      key += '';
      o.data[key] = (type.isString(val)) ? val : JSON.stringify(val);
    }
  }
  return this;
};


/**
 * Domains subclass
 */
function Domains() {}
Domains.prototype = new Base('Domains');

/**
 * Entry point for Domains subclass
 */
Base.prototype.domains = function (input) {
  this.removeSubClassMethods();
  var dom = new Domains();
  if (envCheck()) {
    if (type.isObject(input)) {
      Object.keys(input).forEach(function (key) {
        dom.add(key, input[key]);
      });
    }
  }
  return dom;
};

/**
 * Domains subclass methods
 */
Domains.prototype.add = function (key, val) {
  if (this.subclassMatches('Domains', 'add') && envCheck()) {

    if (Object.keys(reserved).indexOf(key) >= 0) {
      error("reserves the '" + key + "' domain for " + reserved[key]);
    }

    o.domains[key] = path.resolve(val);
    if (!path.existsSync(o.domains[key])) {
      error('could not resolve the ' + key + ' domain - ' + o.domains[key] + ' does not exist');
    }
  }
  return this;
};


/**
 * Libraries subclass
 */
function Libraries() {}
Libraries.prototype = new Base('Libraries');

/**
 * Entry point for Libraries subclass
 */
Base.prototype.libraries = function (list, dir, target) {
  this.removeSubClassMethods();
  var libs = new Libraries();
  if (envCheck()) {
    libs.list(list).path(dir).target(target);
  }
  return libs;
};

/**
 * Libraries subclass methods
 */
Libraries.prototype.list = function (list) {
  if (this.subclassMatches('Libraries', 'list') && envCheck()) {
    if (type.isArray(list)) {
      o.libFiles = list;
    }
  }
  return this;
};

Libraries.prototype.path = function (dir) {
  if (this.subclassMatches('Libraries', 'path') && envCheck()) {
    if (type.isString(dir)) {
      dir = path.resolve(dir);
      if (!path.existsSync(dir)) {
        error('could not resolve the libraries path - ' + dir + ' does not exist');
      }
      o.libDir = dir;
    }
  }
  return this;
};

Libraries.prototype.target = function (target) {
  if (this.subclassMatches('Libraries', 'target') && envCheck()) {
    if (target) {
      o.libsOnlyTarget = target + '';
    }
  }
  return this;
};


/**
 * Analysis subclass
 */
function Analysis() {}
Analysis.prototype = new Base('Analysis');

/**
 * Entry point for Analysis subclass
 */
Base.prototype.analysis = function (target, prefix, suffix, hide) {
  this.removeSubClassMethods();
  var ana = new Analysis();
  if (envCheck()) {
    ana.output(target).prefix(prefix).suffix(suffix).hide(hide);
  }
  return ana;
};

/**
 * Analysis subclass methods
 */
Analysis.prototype.output = function (target) {
  if (this.subclassMatches('Analysis', 'output') && envCheck()) {
    if (type.isString(target)) {
      o.treeTarget = path.resolve(target);
    }
  }
  return this;
};

Analysis.prototype.prefix = function (prefix) {
  if (this.subclassMatches('Analysis', 'prefix') && envCheck()) {
    o.domPrefix = !!prefix;
  }
  return this;
};

Analysis.prototype.suffix = function (suffix) {
  if (this.subclassMatches('Analysis', 'suffix') && envCheck()) {
    o.extSuffix = !!suffix;
  }
  return this;
};

Analysis.prototype.hide = function (domain) {
  if (this.subclassMatches('Analysis', 'suffix') && envCheck()) {
    if (type.isArray(domain)) {
      var that = this;
      domain.forEach(function (d) {
        that.hide(d);
      });
    }
    else if (type.isString(domain)) {
      if (domain === 'app') {
        (o.logger || logule).warn("cannot ignore the app domain");
      }
      else {
        o.ignoreDoms.push(domain);
      }
    }
  }
  return this;
};


/**
 * Arbiters subclass
 */
function Arbiters() {}
Arbiters.prototype = new Base('Arbiters');

/**
 * Entry point for Arbiters subclass
 */
Base.prototype.arbiters = function (arbObj) {
  this.removeSubClassMethods();
  var arb = new Arbiters();

  if (envCheck()) {
    if (type.isObject(arbObj)) {
      Object.keys(arbObj).forEach(function (key) {
        arb.add(key, arbObj[key]);
      });
    }
    else if (type.isArray(arbObj)) {
      arbObj.forEach(function (a) {
        arb.add(a);
      });
    }
  }
  return arb;
};

/**
 * Arbiters subclass methods
 */
Arbiters.prototype.add = function (name, globs) {
  if (this.subclassMatches('Arbiters', 'add') && envCheck()) {
    if (type.isArray(globs) && name) {
      globs = globs.filter(function (e) {
        return (type.isString(e) && e !== '');
      });
      o.arbiters[name] = (globs.length === 0) ? name : globs;
    } else if (type.isString(globs) && globs !== '') {
      o.arbiters[name] = [globs];
    } else {
      o.arbiters[name] = [name];
    }
  }
  return this;
};

/**
 * End point of the chain if in the right environment
 * compile initiates the one time call to the bundler
 */
Base.prototype.compile = function (target) {
  this.removeSubClassMethods();
  if (envCheck()) {
    o.target = path.resolve(target);
    o.logger = o.logger || logule;
    o.exts = ['', '.js', '.coffee'].concat(Object.keys(o.compilers)); //TODO: necessary now?
    bundle(o);
    // Dont return here
  }
  return this;
};



// internal mini-tests
if (module === require.main) {
  var modul8 = {
    minifier: function () {},
    testcutter: function () {}
  };
  module.exports('app.cs')
  .set('domloader', function (code) {
    return code;
  })
  .set('namespace', 'QQ')
  .set('logging', 'INFO')
  .register('.cs', function (code, bare) {
    return code;
  })
  .before(modul8.testcutter)
  .libraries()
    .list(['jQuery.js', 'history.js'])
    .path('/app/client/libs/')
    .target('dm-libs.js')
  .arbiters()
    .add('jQuery', ['$', 'jQuery'])
    .add('Spine')
  .arbiters({
    'underscore': 'underscore',
    '_': '_'
  })
  .domains()
    .add('app', '/app/client/')
    .add('shared', '/app/shared/')
  .data()
    .add('models', '{modeldata:{getssenttoclient}}')
    .add('versions', {'users/view': [0, 2, 5]})
  .analysis()
    .prefix(true)
    .suffix(false)
  .in('development')
    .output(console.log)
  .in('production')
    .output('filepath!')
  .in('all')
    .after(modul8.minifier)
    .compile('dm.js');
}

