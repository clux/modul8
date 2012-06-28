var path      = require('path')
  , modul8    = require('../')
  , utils     = require('../lib/utils')
  , dirify    = require('./lib/dirify')
  , test      = require('tap').test
  , log       = require('logule').sub('PLUGIN')
  , join      = path.join
  , dir       = __dirname
  , compile   = utils.makeCompiler();


var data = {
  a: {str: 'hello thar'}
, b: {coolObj: {}}
, c: 5
, d: [2, 3, "abc", {'wee': []}]
, e: {str2: 9 + 'abc'}
};

function PluginOne(name) {
  this.name = 'plug1';
}
PluginOne.prototype.data = function () {
  return data;
};
PluginOne.prototype.domain = function () {
  return join(dir, 'plugins', 'dom');
};

function PluginTwo(name) {
  this.name = 'plug2';
}
PluginTwo.prototype.data = function () {
  return JSON.stringify(data);
};

function generateApp() {
  dirify('plugins', {
    dom   : {
      'code1.js' : "module.exports = require('./code2');"
    , 'code2.js' : "module.exports = 160;"
    , 'code3.js' : "module.exports = 320;"
    }
  , main  : {
      'entry.js'  : "require('plug1::code1');"
    }
  });


  modul8(join(dir, 'plugins', 'main', 'entry.js'))
    .set('namespace', 'QQ')
    .logger(log.sub().suppress('info', 'debug'))
    .use(new PluginOne())
    .use(new PluginTwo())
    .data(data)
      .add('crazy1', 'new Date()')
      .add('crazy2', '(function(){return new Date();})()')
      .add('crazy3', 'window')
    .compile(join(dir, 'output', 'plugins.js'));
}

test("plugins", function (t) {
  generateApp();
  var brain     = require('./lib/brain')(t)

  var mainCode = compile(join(dir, 'output', 'plugins.js'));
  brain.do(mainCode);

  // sanity
  brain.ok("!!QQ", "global namespace is defined");
  brain.ok("!!QQ.require", "require is globally accessible");
  brain.type("QQ.require", 'function', "require is a function");

  // plug1 exports the right code
  brain.ok("!QQ.require('plug1::code')", "plug1 does not export code when not required");
  brain.ok("QQ.domains().indexOf('plug1') >= 0", "plug1 was exported as a domain");
  brain.equal("QQ.require('plug1::code1')", 160, "plug1::code1 is included as it is required");
  brain.equal("QQ.require('plug1::code2')", 160, "plug1:;code2 is included as it is required by a required module");
  brain.ok("!QQ.require('plug1::code3')", "plug1::code3 is NOT included as it is NOT required");

  // plug2 exports nothing
  brain.equal("QQ.domains().indexOf('plug2')", -1, "plug2 did not export a domain");

  // both export data
  brain.ok("!!QQ.require('data::plug1')", "plug1 exports data");
  brain.ok("!!QQ.require('data::plug2')", "plug2 exports data");

  Object.keys(data).forEach(function (key) {
    brain.ok("QQ.require('data::plug1')." + key, "require('data::plug1')." + key + " exists");
    brain.deepEqual("QQ.require('data::plug1')." + key, data[key], "require('data::plug1')." + key + " is data['" + key + "']");
    brain.ok("QQ.require('data::plug2')." + key, "require('data::plug2')." + key + " exists");
    brain.deepEqual("QQ.require('data::plug2')." + key, data[key], "require('data::plug2')." + key + " is data['" + key + "']");
  });
  // plugin tests over

  // check that crazy data is included
  brain.ok("QQ.require('data::crazy1')", "require('data::crazy1') exists");
  brain.ok("QQ.require('data::crazy2')", "require('data::crazy2') exists");
  brain.ok("QQ.require('data::crazy3')", "require('data::crazy3') exists");
  brain.ok("QQ.require('data::crazy1').getDay", "require('data::crazy1') is an instance of Date");
  brain.ok("QQ.require('data::crazy2').getDay", "require('data::crazy2') is an instance of Date");
  brain.ok("QQ.require('data::crazy3').QQ", "require('data::crazy3') returns window (found namespace)");

  Object.keys(data).forEach(function (key) {
    var val = data[key];
    // viewing data
    brain.ok("QQ.require('data::" + key + "')", "require('data::" + key + "') exists");
    brain.deepEqual("QQ.require('data::" + key + "')", data[key], "require('data::" + key + "') is data[" + key + "]");

    // crud interface tool
    brain.do("var dataMod = QQ.data;");

    // creating databrowser.evaluate(
    brain.do("dataMod('newKey', 'arst')");
    brain.equal("QQ.require('data::newKey')", 'arst', "can create new data key");

    // editing data
    brain.type("dataMod", 'function', "M8::data is a requirable function");
    brain.do("dataMod('" + key + "','hello')");
    brain.equal("QQ.require('data::" + key + "')", 'hello', "can call data overriding method on data::" + key);

    // deleting data
    brain.do("dataMod('" + key + "')");
    brain.equal("QQ.require('data::" + key + "')", undefined, "successfully deleted data::" + key);
  });

  t.end();
});
