var fs      = require('fs')
  , join    = require('path').join
  , modul8  = require('../')
  , dirify  = require('./lib/dirify')
  , log     = require('logule').sub('ARBITER')
  , brain   = require('./lib/brain')()
  , utils   = require('../lib/utils');

var root = join(__dirname, 'arbiters')
  , output  = join(__dirname, 'output')
  , compile = utils.makeCompiler();

var out = {
  app  : join(output, 'arbiters.js')
, libs : join(output, 'arbiterslibs.js')
};

function setup() {
  dirify('arbiters', {
    app  : {
      'r.js'      : "module.exports = 'app';" // same name as lib arbiter to verify most work
    , 'entry.js'  : "require('./r');"
    }
  , libs : {
      'lib.js'  : "(function(){window.libVar = 'lib';}());"
    }
  });

  //log.trace('compiling');
  modul8(join(root, 'app', 'entry.js'))
    .logger(log.sub().suppress('info', 'warn', 'debug'))
    //.analysis(console.log)
    .arbiters({'r': 'libVar'})
    .libraries()
      .list(['lib.js'])
      .path(join(root, 'libs'))
      .target(out.libs)
    .compile(out.app);
}


exports["test arbiters"] = function () {
  setup();

  var libCode = compile(out.libs)
    , appCode = compile(out.app)
    , count = 4;

  brain.isUndefined(libCode, "compiled libCode evaluates successfully");
  brain.ok("window.libVar === 'lib'", "global libVar exists before arbiters kick in");

  brain.isUndefined(appCode, "compiled app code evaluates successfully");
  brain.isDefined("M8", "global namespace is defined");
  // everything evaluated now

  brain.equal("M8.require('app::r.js')", "app", "can require app::r.js when 'r' is an arbiter key");
  brain.equal("M8.require('./r.js')", "app", "can require ./r.js when 'r' is an arbiter key");
  count += 2;

  brain.equal("M8.require('M8::r')", "lib", "can require arbitered libVar through M8::");
  brain.equal("M8.require('r')", "lib", "can require arbitered libVar globally even when ./r exists");
  brain.isUndefined("window.libVar", "window.libVar has been deleted");
  count += 3;

  log.info('completed', count, 'arbiter requires');
};

