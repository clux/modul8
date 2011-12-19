var fs      = require('fs')
  , path    = require('path')
  , zombie  = require('zombie')
  , assert  = require('assert')
  , rimraf  = require('rimraf')
  , mkdirp  = require('mkdirp').sync
  , utils   = require('../lib/utils')
  , modul8  = require('../')
  , cli     = require('../bin/cli')
  , join    = path.join
  , dir     = __dirname
  , compile = utils.makeCompiler()
  , testCount = 0
  , num_tests = 8;

function testsDone(count) {
  testCount += count;
  num_tests -= 1;
  if (!num_tests) {
    console.log('cli#complex - completed:', testCount);
  }
}

function callCLI(str) {
  var base = ["coffee", "./bin/cli.js"]
    , argv = base.concat(str.split(' '));
  cli(argv);
}

exports["test CLI#examples/simple"] = function () {
  var browser = new zombie.Browser()
    , workDir = './examples/simple/'
    , str = "" + workDir + "app/app.js -a jQuery=jQuery,$ -w jQuery -o " + workDir + "cliout.js";

  callCLI(str);

  browser.visit('file:///' + dir + "/empty.html", function (err, browser, status) {
    if (err) {
      throw err;
    }
    var libs = compile(workDir + 'libs/jquery.js')
      , mainCode = compile(workDir + 'cliout.js');

    assert.isUndefined(browser.evaluate(libs, "libs evaluate successfully"));
    assert.isUndefined(browser.evaluate(mainCode, ".compile() result evaluates successfully"));
    assert.isDefined(browser.evaluate("M8.require('jQuery')", "jQuery is requirable"));
    assert.isUndefined(browser.evaluate("window.jQuery", "jQuery is not global"));
    assert.isUndefined(browser.evaluate("window.$", "$ is not global"));

    console.log('CLI#examples/simple - completed:', 5);
  });
};

function initDirs(num) {
  var folders = ['libs', 'main', 'plug', 'dom'];
  for (var i = 0; i < num; i += 1) {
    folders.forEach(function (folder) {
      mkdirp(join(dir, 'cli', i + '', folder), '0755'); //TODO: fn in loop
    });
  }
  /*dirify('cli', {
    libs : {}
  , main : {}
  , plug : {}
  , dom  : {}
  });*/

}

function generateApp(opts, i) {
  var entry = []
    , plug = [];

  plug.push("Plugin = function(name){this.name = (name != null) ? name : 'defaultName';};");
  plug.push("Plugin.prototype.data = function(){return {plugData:true};};");
  plug.push("exports.Plugin = Plugin;");

  entry.push("exports.libTest1 = !!window.libTest1;");
  entry.push("exports.libTest2 = !!window.libTest2;");

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

exports["test CLI#complicated"] = function () {
  var num = num_tests;
  initDirs(num);
  var runCase = function (k) {
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

    var workDir = dir + '/cli/' + k + '/'
      , flags = ["" + workDir + "main/entry.js"];

    if (opts.dom) {
      flags.push("-p dom=" + workDir + "dom/");
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
      flags.push("-d dataKey=" + workDir + "data.json");
    }
    if (opts.plug) {
      flags.push("-g " + workDir + "plug/");
    }
    flags.push("-o " + workDir + "output.js");
    if (opts.lib1Arb && opts.lib2Arb) {
      flags.push("-a lib1&lib2=libTest2");
    } else if (opts.lib1Arb) {
      flags.push("-a lib1");
    } else if (opts.lib2Arb) {
      flags.push("-a lib2=libTest2");
    }

    callCLI(flags.join(' '));

    var ns = opts.ns || 'M8';
    var browser = new zombie.Browser();
    browser.visit('file:///' + dir + "/empty.html", function (err, browser, status) {
      if (err) {
        throw err;
      }
      var mainCode = compile(workDir + 'output.js')
        , libs1 = compile(workDir + 'libs/lib1.js')
        , libs2 = compile(workDir + 'libs/lib2.js')
        , count = 0;
      browser.evaluate(libs1);
      browser.evaluate(libs2);

      if (opts.lib1Arb) {
        assert.isUndefined(browser.evaluate("window.lib1", "lib1 globals exist"));
        count += 1;
      } else {
        assert.isDefined(browser.evaluate("window.lib1", "lib1 global has been removed"));
        assert.type(browser.evaluate("window.lib1"), "function", "lib1 is a function");
        count += 2;
      }

      assert.isUndefined(browser.evaluate(mainCode), ".compile() result evaluates successfully");
      assert.isDefined(browser.evaluate(ns), "namespace exists");
      assert.isDefined(browser.evaluate(ns + ".require"), "require fn exists");
      assert.isDefined(browser.evaluate(ns + ".require('./entry')"), "can require entry point run " + k);
      count += 4;

      if (opts.lib1Arb) {
        assert.isDefined(browser.evaluate(ns + ".require('lib1')", "lib1 is arbitered"));
        count += 1;
      }
      if (opts.lib2Arb) {
        assert.isDefined(browser.evaluate(ns + ".require('lib2')", "lib2 is arbitered correctly"));
        count += 1;
      }
      if (opts.data) {
        assert.isDefined(browser.evaluate(ns + ".require('data::dataKey')", "can require dataKey"));
        assert.isDefined(browser.evaluate(ns + ".require('./entry').data", "data was also required via entry"));
        count += 2;
      }
      if (opts.dom) {
        assert.isDefined(browser.evaluate(ns + ".require('dom::')", "domain can be required"));
        assert.isDefined(browser.evaluate(ns + ".require('./entry').domain", "domain was successfully required from entry too"));
        count += 2;
      }
      testsDone(count);
    });
  };

  for (var k = 0; k < num; k += 1) {
    runCase(k);
  }
};

