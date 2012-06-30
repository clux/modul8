var fs      = require('fs')
  , zombie  = require('zombie') //TODO: brain!
  , assert  = require('assert')
  , rimraf  = require('rimraf')
  , log     = require('logule').sub('CLI').suppress('trace')
  , mkdirp  = require('mkdirp').sync
  , join    = require('path').join
  , utils   = require('../lib/utils')
  , modul8  = require('../')
  , test    = require('tap').test
  , cli     = require('../bin/cli')
  , dir     = __dirname
  , compile = utils.makeCompiler()
  , makeBrain = require('./lib/brain')
  , testCount = 0
  , num_tests = 8;

function callCLI(str) {
  var base = ["node", "./bin/cli.js"]
    , argv = base.concat(str.split(' '));
  log.trace('call: ', str);
  cli(argv);
}
/*
test("CLI/simple", function (t) {
  var brain   = makeBrain(t)
    , workDir = join('..', 'examples', 'simple')
    , str = join(workDir, 'app', 'app.js') + " -a jQuery=jQuery,$ -w jQuery -o " + join(workDir, "cliout.js");

  callCLI(str);

  var libs = compile(join(workDir, 'libs', 'jquery.js'))
    , mainCode = compile(join(workDir, 'cliout.js'));

  brain.do(libs);
  brain.do(mainCode);
  brain.ok("M8.require('jQuery') !== undefined", "jQuery is requirable");
  brain.ok("window.jQuery === undefined", "jQuery is not global");
  brain.ok("window.$ === undefined", "$ is not global");
  t.end();
});
*/

function initDirs(num) {
  var folders = ['libs', 'main', 'plug', 'dom'];
  var fn = function (k) {
    folders.forEach(function (folder) {
      mkdirp(join(dir, 'cli', k + '', folder), '0755');
    });
  };
  for (var i = 0; i < num; i += 1) {
    fn(i);
  }
}


function generateApp(opts, i) {
  var entry = []
    , plug = [];

  plug.push("Plugin = function(name){this.name = (name != null) ? name : 'defaultName';};");
  plug.push("Plugin.prototype.data = function(){return {plugData:true};};");
  plug.push("exports.Plugin = Plugin;");

  entry.push("exports.libTest1 = window.libTest1 !== undefined;");
  entry.push("exports.libTest2 = window.libTest2 !== undefined;");

  if (opts.data) {
    entry.push("exports.data = !!require('data::dataKey').hy;");
  }
  if (opts.plug) {
    entry.push("exports.plugData = !!require('data::" + (opts.plugName || 'defaultName') + "');");
  }
  if (opts.dom) {
    entry.push("exports.domain = !!require('dom::');");
  }
  if (opts.testcutter) {
    entry.push("if (module === require.main) { require('server-requirement'); }");
  }

  fs.writeFileSync(join(dir, 'cli', i + '', 'main', 'entry.js'), entry.join('\n'));
  fs.writeFileSync(join(dir, 'cli', i + '', 'dom', 'index.js'), "module.exports = 'domainCode';");
  fs.writeFileSync(join(dir, 'cli', i + '', 'libs', 'lib1.js'), "window.lib1 = function(fn){fn();};");
  fs.writeFileSync(join(dir, 'cli', i + '', 'libs', 'lib2.js'), "window.libTest2 = 'lib2';");

  if (opts.plug) {
    fs.writeFileSync(join(dir, 'cli', i + '', 'plug', 'index.js'), plug.join('\n'));
  }
  if (opts.data) {
    fs.writeFileSync(join(dir, 'cli', i + '', 'data.json'), JSON.stringify({
      hy: 'thear',
      wee: 122
    }));
  }
  fs.writeFileSync(join(dir, 'cli', i + '', 'main', 'temp.js'), "require('./code1')");
}

function runCase(k, t) {
  var opts = {
    dom       : k % 2 === 0
  , data      : k % 4 === 0
  , plug      : k % 8 === 0
  , libArb1   : k % 2 === 0
  , libArb2   : k % 4 === 0
  , wrapper   : k % 8 === 1
  , minifier  : k % 4 === 1
  , testcutter: k % 5 === 1
  };

  if (k % 3 === 0) {
    opts.ns = 'WOWZ';
  }
  generateApp(opts, k);

  var workDir = join(__dirname, 'cli', k + '')
    , flags = [join(workDir, "main", "entry.js")];

  if (opts.dom) {
    flags.push("-p dom=" + join(workDir, 'dom')); //TODO: used to have a slash at the end
  }
  if (opts.testcutter) {
    flags.push("-t");
  }
  if (opts.minifier) {
    flags.push("-m");
  }
  if (opts.wrapper) {
    flags.push("-w lib1");
  }
  if (opts.ns) {
    flags.push("-n " + opts.ns);
  }
  if (opts.data) {
    flags.push("-d dataKey=" + join(workDir, 'data.json'));
  }
  if (opts.plug) {
    flags.push("-g " + join(workDir, 'plug')); //TODO: used to have a slash
  }
  flags.push("-o " + join(workDir, 'output.js'));
  if (opts.lib1Arb && opts.lib2Arb) {
    flags.push("-a lib1&lib2=libTest2");
  } else if (opts.lib1Arb) {
    flags.push("-a lib1");
  } else if (opts.lib2Arb) {
    flags.push("-a lib2=libTest2");
  }

  callCLI(flags.join(' '));

  // check output

  var mainCode = compile(join(workDir, 'output.js'))
    , libs1 = compile(join(workDir, 'libs', 'lib1.js'))
    , libs2 = compile(join(workDir, 'libs', 'lib2.js'))
    , ns = opts.ns || 'M8'
    , brain = makeBrain(t);

  brain.do(libs1);
  brain.do(libs2);

  if (opts.lib1Arb) {
    brain.ok("!window.lib1", "lib1 global removed");
  } else {
    brain.ok("!!window.lib1", "lib1 global has exists");
    brain.type("window.lib1", "function", "lib1 is a function");
  }

  brain.do(mainCode);
  brain.ok(ns, "namespace exists");
  brain.ok(ns + ".require", "require fn exists");
  brain.ok("!!" + ns + ".require('./entry')", "can require entry point run " + k);

  if (opts.lib1Arb) {
    brain.ok("!!" + ns + ".require('lib1')", "lib1 is arbitered");
  }
  if (opts.lib2Arb) {
    brain.ok("!!" + ns + ".require('lib2')", "lib2 is arbitered correctly");
  }
  if (opts.data) {
    brain.ok("!!" + ns + ".require('data::dataKey')", "can require dataKey");
    brain.ok("!!" + ns + ".require('./entry').data", "data was also required via entry");
  }
  if (opts.dom) {
    brain.ok("!!" + ns + ".require('dom::')", "domain can be required");
    brain.ok("!!" + ns + ".require('./entry').domain", "domain was successfully required from entry too");
  }
  testsDone(t);
}

function testsDone (t) {
  num_tests -= 1;
  if (!num_tests) {
    t.end();
  }
}

test("CLI complex", function (t) {
  var num = num_tests;
  initDirs(num);

  for (var k = 0; k < num; k += 1) {
    runCase(k, t);
  }
});

