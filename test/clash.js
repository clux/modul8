var fs      = require('fs')
  , rimraf  = require('rimraf')
  , join    = require('path').join
  , log     = require('logule').sub('CLASH')
  , brain   = require('./lib/brain')()
  , utils   = require('../lib/utils')
  , modul8  = require('../');

var root = join(__dirname, 'clash')
  , exts = ['.js', '.coffee']
  , output = join(__dirname, 'output', 'clash.js');

var domains = {
  app    : join(root, 'app')
, shared : join(root, 'shared')
};

function makeFiles(domain, name, num) {
  var ext1 = (name === 'clash') ? exts[0] : exts[num]     // clash tests with outer ext fixed
    , ext2 = (name === 'revclsh') ? exts[0] : exts[num]   // revclash tests with inner ext fixed
    , dom = join(root, domain);

  if (name !== 'safe') {                                  // safe tests without ambiguous file/folder pairs existing
    fs.writeFileSync(join(dom, name + num + ext1), "module.exports = 'outside'");
  }
  fs.writeFileSync(join(dom, name + num, 'index' + ext2), "module.exports = 'inside'");
}

function generateApp() {
  try {
    rimraf.sync(root);
  } catch (e) {}
  fs.mkdirSync(root, '0755');

  var l = [];
  Object.keys(domains).forEach(function (domain) {
    var dom = join(root, domain)
      , prefix = (domain === 'app') ? '' : domain + '::';

    fs.mkdirSync(dom, '0755');

    for (var i = 0; i < exts.length; i += 1) {
      fs.mkdirSync(join(dom, 'safe' + i), '0755');
      fs.mkdirSync(join(dom, 'unsafe' + i), '0755');
      fs.mkdirSync(join(dom, 'clash' + i), '0755');
      fs.mkdirSync(join(dom, 'revclash' + i), '0755');

      l = l.concat([
        "exports." + domain + "_safe" + i + "slash = require('" + prefix + "safe" + i + "/');"
      , "exports." + domain + "_safe" + i + " = require('" + prefix + "safe" + i + "');"

      , "exports." + domain + "_unsafe" + i + "slash = require('" + prefix + "unsafe" + i + "/');"
      , "exports." + domain + "_unsafe" + i + " = require('" + prefix + "unsafe" + i + "');"

      , "exports." + domain + "_clash" + i + "slash = require('" + prefix + "clash" + i + "/');"
      , "exports." + domain + "_clash" + i + " = require('" + prefix + "clash" + i + "');"

      , "exports." + domain + "_revclash" + i + "slash = require('" + prefix + "revclash" + i + "/');"
      , "exports." + domain + "_revclash" + i + " = require('" + prefix + "revclash" + i + "');"
      ]);

      makeFiles(domain, 'safe', i);
      makeFiles(domain, 'unsafe', i);
      makeFiles(domain, 'clash', i);
      makeFiles(domain, 'revclash', i);
    }
  });
  var entry = join(domains.app, 'entry.js');
  fs.writeFileSync(entry, l.join('\n'));

  //log.trace('compiling')
  modul8(entry)
    .domains({shared: domains.shared})
    .logger(log.sub().suppress('info', 'debug'))
    //.analysis(console.log)
    .register('.coffee', function (code) {
      return code + ';'
    })
    .compile(output);
}

exports["test clashes"] = function () {
  generateApp();

  var compile = utils.makeCompiler()
    , mainCode = compile(output)
    , testCount = 3;

  brain.isUndefined(mainCode, ".compile() result evaluates successfully");
  brain.isDefined("M8", "global namespace is defined");
  brain.isDefined("M8.require('entry')", "entry can be required")

  Object.keys(domains).forEach(function (dom) {
    for (var i = 0; i < exts.length; i += 1) {
      var reqStr = "M8.require('entry')." + dom + "_";

      brain.equal(reqStr + "safe" + i + "slash", 'inside', dom + "_safe" + i + "slash is defined and is inside");
      brain.equal(reqStr + "safe" + i, 'inside', dom + "_safe" + i + " is defined and is inside");

      brain.equal(reqStr + "unsafe" + i + "slash", 'inside', dom + "_unsafe" + i + "slash is defined and is inside");
      brain.equal(reqStr + "unsafe" + i, 'outside', dom + "_unsafe" + i + " is defined and is outside");

      brain.equal(reqStr + "clash" + i + "slash", 'inside', dom + "_clash" + i + "slash is defined and is inside");
      brain.equal(reqStr + "clash" + i, 'outside', dom + "_clash" + i + " is defined and is outside");

      brain.equal(reqStr + "revclash" + i + "slash", 'inside', dom + "_revclash" + i + "slash is defined and is inside");
      brain.equal(reqStr + "revclash" + i, 'outside', dom + "_revclash" + i + " is defined and is outside");
      testCount += 8;
    }
  });
  log.info('verified', testCount, 'collision prone requires');
};
