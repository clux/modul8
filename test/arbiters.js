var fs      = require('fs')
  , join    = require('path').join
  , test     = require('tap').test
  , modul8  = require('../')
  , dirify  = require('./lib/dirify')
  , log     = require('logule').sub('ARBITER')
  , utils   = require('../lib/utils');

var root = join(__dirname, 'arbiters')
  , output  = join(__dirname, 'output')
  , compile = utils.makeCompiler();

var out = {
  app  : join(output, 'arbiters.js')
, libs : join(output, 'arbiterslibs.js')
};

function setup () {
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


test("arbiters", function (t) {
  setup();
  var brain   = require('./lib/brain')(t)

  var libCode = compile(out.libs)
    , appCode = compile(out.app);

  brain.do(libCode);
  brain.ok("window.libVar === 'lib'", "global libVar exists before arbiters kick in");

  brain.do(appCode);
  brain.ok("window.M8 !== undefined", "global namespace is defined");
  // everything evaluated now

  brain.equal("M8.require('app::r.js')", "app", "can require app::r.js when 'r' is an arbiter key");
  brain.equal("M8.require('./r.js')", "app", "can require ./r.js when 'r' is an arbiter key");

  brain.equal("M8.require('M8::r')", "lib", "can require arbitered libVar through M8::");
  brain.equal("M8.require('r')", "lib", "can require arbitered libVar globally even when ./r exists");
  brain.ok("window.libVar === undefined", "window.libVar has been deleted");

  t.end();
});

