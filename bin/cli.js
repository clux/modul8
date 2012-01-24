#!/usr/bin/env node

var fs = require('fs')
  , path = require('path')
  , program = require('../node_modules/commander')
  , modul8 = require('../')
  , utils = require('../lib/utils')
  , dir = fs.realpathSync()
  , basename = path.basename
  , dirname = path.dirname
  , resolve = path.resolve
  , join = path.join;

// parse query string like options in two ways
function makeQsParser(isValueList) {
  return function (val) {
    var out = {};
    (val.split('&') || []).forEach(function (e) {
      var pair = e.split('=')
        , k = pair[0]
        , v = pair[1];
      out[k] = v;
      if (isValueList && v) {
        out[k] = v.split(',');
      }
    });
    return out;
  };
}

var simpleQs = makeQsParser(0)
  , listQs = makeQsParser(1);

// options

program
  .version(modul8.version)
  .option('-z, --analyze', 'analyze dependencies instead of compiling')
  .option('-p, --domains <name=path>', 'specify require domains', simpleQs)
  .option('-d, --data <key=path>', 'attach json data from path to data::key', simpleQs)

  .option('-b, --libraries <path=lib1,lib2>', 'include listed libraries first', listQs)
  .option('-a, --arbiters <shortcut=glob,glob2>', 'arbiter list of globals to shortcut', listQs)
  .option('-g, --plugins <path=arg,arg2>', 'load plugins from module path using constructor arguments', listQs)

  .option('-o, --output <file>', 'direct output to a file')
  .option('-l, --logging <level>', 'set the logging level')
  .option('-n, --namespace <name>', 'specify the target namespace used in the compiled file')
  .option('-w, --wrapper <fnName>', 'name of wrapping domloader function')
  .option('-t, --testcutter', 'cut out inlined tests in scanned files')
  .option('-m, --minifier', 'enable uglifyjs minification');

program.on('--help', function () {
  console.log('  Examples:');
  console.log('');
  console.log('    # analyze application dependencies from entry point');
  console.log('    $ modul8 app/entry.js -z');
  console.log('');
  console.log('    # compile application from entry point');
  console.log('    $ modul8 app/entry.js > output.js');
  console.log('');
  console.log('    # specify extra domains');
  console.log('    $ modul8 app/entry.js -p shared=shared/&bot=bot/');
  console.log('');
  console.log('    # specify arbiters');
  console.log('    $ modul8 app/entry.js -a jQuery=$,jQuery&Spine');
  console.log('');
  console.log('    # wait for the DOM using the jQuery function');
  console.log('    $ modul8 app/entry.js -w jQuery');
  console.log('');
});

function complete() {
  // first arg must be entry
  var entry = program.args[0];
  if (!entry) {
    console.error("usage: modul8 entry [options]");
    console.log("or modul8 -h for help");
    process.exit();
  }

  // utils
  var i_d = function (a) {
    return a;
  };

  var construct = function (Ctor, args) {
    var F;
    F = function () {
      return Ctor.apply(this, args);
    };
    F.prototype = Ctor.prototype;
    return new F();
  };

  // convenience processing of plugins and data input
  var plugins = [];
  Object.keys(program.plugins || {}).forEach(function (name) {
    var optAry = program.plugins[name];
    if (!name) {
      console.error("invalid plugin usage: -g path=[args]");
      process.exit();
    }
    var rel = join(fs.realpathSync(), name);
    if (path.existsSync(rel)) {
      name = rel;
    }
    // path can be absolute, relative to execution directory, or relative to CLI dir
    var P;
    try {
      P = require(name).Plugin;
    }
    catch (e) {
      console.error("invalid plugin: " + name + "could not be resolved");
      process.exit();
    }
    plugins.push(construct(P, optAry));
  });

  Object.keys(program.data || {}).forEach(function (k) {
    var p = program.data[k];
    if (!p || !path.existsSync(p)) {
      console.error("invalid data usage: value must be a path to a file");
      process.exit();
    }
    program.data[k] = fs.readFileSync(p, 'utf8');
  });

  if (!program.output) {
    program.output = console.log;
  }

  var libPath = Object.keys(program.libraries || {})[0]
    , libs = (program.libraries || {})[libPath];

  modul8(entry)
    .set('logging', program.logging || 'ERROR')
    .set('namespace', program.namespace || 'M8')
    .set('domloader', program.wrapper || '')
    .set('force', true) // bypass persister
    .use(plugins)
    .before(program.testcutter ? modul8.testcutter : i_d)
    .after(program.minifier ? modul8.minifier : i_d)
    .domains(program.domains)
    .data(program.data)
    .analysis(program.analyze ? console.log : void 0)
    .arbiters(program.arbiters)
    .libraries(libs || [], libPath)
    .compile(program.analyze ? false : program.output);
}

if (module === require.main) {
  program.parse(process.argv);
  complete();
}

// allow injecting of custom argv to test cli
module.exports = function (argv) {
  program.parse(argv);
  complete();

  // reset state which program retains between multiple calls from same file
  var resettables = [
    'analyze'     // -z
  , 'data'        // -d
  , 'domains'     // -p
  , 'namespace'   // -n
  , 'testcutter'  // -t
  , 'minifier'    // -m
  , 'wrapper'     // -w
  , 'output'      // -o
  , 'arbiters'    // -a
  , 'logging'     // -l
  , 'plugins'     // -g
  , 'libraries'   // -b
  ];

  resettables.forEach(function (k) {
    delete program[k];
  });
};

