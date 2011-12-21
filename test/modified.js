var assert = require('assert')
  , fs = require('fs')
  , modul8 = require('../index.js')
  , join = require('path').join
  , dirify = require('./dirify')
  , read = require('../lib/utils').read;

var root = join(__dirname, 'modified')
  , out = join(__dirname, 'output');

var paths = {
  app     : join(root, 'app')
, shared  : join(root, 'shared')
, libs    : join(root, 'libs')
};

var out = {
  app   : join(out, 'outmod.js')
, libs  : join(out, 'outlibs.js')
};


function sleep(ms) {
  var now = new Date().getTime();
  while (new Date().getTime() < now + ms) {}
}

var mTimesOld = {
  app  : 0
, libs : 0
};

function modify(type) {
  var file = join(paths[type], '0.js');
  sleep(1005);
  fs.writeFileSync(file, read(file) + ';');
  sleep(1005);
}


function wasUpdated(type) {
  var mtime = fs.statSync(out[type]).mtime.valueOf()
    , didUpdate = (mtime !== mTimesOld[type]);

  if (didUpdate) {
    mTimesOld[type] = mtime;
  }
  return didUpdate;
}


function makeApp() {
  dirify('modified', {
    shared: { '0.js' : "module.exports = 'ok';" }
  , libs  : { '0.js' : "(function(){window.libs = 'ok';}());" }
  , app   : {
      '0.js'         : "module.exports = 'ok';"
    , 'entry.js'     : "exports.app = require('0');" + "exports.shared = require('shared::0');"
    }
  });
}

function compile(useLibs, separateLibs) {
  modul8(join(paths.app, 'entry.js'))
    .set('logging', 'DEBUG')
    .libraries()
      .list(useLibs ? ['0.js'] : [])
      .path(paths.libs)
      .target(separateLibs ? out.libs : false)
    .domains({shared : paths.shared})
    .compile(out.app);
}


function runCase(k) {
  var testCount = 0
    , withLibs = (k === 1 || k === 2)
    , separateLibs = (k === 2);

  Object.keys(paths).forEach(function (name) {
    if (!withLibs && name === 'libs') {
      return;
    }
    var modifyingLibs = (name === 'libs');
    compile(withLibs, separateLibs);

    wasUpdated('app');
    if (separateLibs) {
      wasUpdated('libs');
    }

    // start

    compile(withLibs, separateLibs);
    //console.log("modifying " + name + "::0 using libs? " + withLibs + ". Separately? " + separateLibs);

    assert.ok(!wasUpdated('app'), "preparing to modify " + name + "::0 - recompile does not change libs mTimes without changes");

    if (separateLibs) {
      assert.ok(!wasUpdated('libs'), "preparing to modify " + name + "::0 - recompile does not change libs mTimes without changes");
      testCount += 1;
    }

    // modify sleeps as there is a limited resolution on mtime
    // => cant make rapid changes to files programmatically
    //    and expect modul8 to understand all the time
    // TODO: use fs.(f)utimesSync when we ditch 0.4 compatibility
    modify(name);

    compile(withLibs, separateLibs);
    var appChanged = wasUpdated('app')
      , libsChanged = separateLibs ? wasUpdated('libs') : true;

    if (modifyingLibs && !separateLibs) {
      assert.ok(appChanged, "modified " + name + "::0 - compiling with lib changes for included libs app mtime");
    }
    else if (modifyingLibs && separateLibs) {
      assert.ok(libsChanged, "modified " + name + "::0 - compiling with lib changes for separate libs changes libs mtime");
      assert.ok(!appChanged, "modified " + name + "::0 - compiling with lib changes for separate libs does not change app mtime");
      testCount += 1;
    }
    else if (!modifyingLibs) {
      assert.ok(appChanged, "modified " + name + "::0 - compiling with app changes changes app mtime");
    }
    testCount += 2;
  });
  // each call takes 2*sleepDuration * num_keys [s]
  // == 2* ~1 * 3 || 2 * ~1 * 2 == 6 || 4

  return testCount;
}

exports["test compile#modified"] = function () {
  if (false) {
    console.log('compile#modified on hold - skipping 24 second test');
    return;
  }
  makeApp();
  compile();
  wasUpdated('app');
  /*TestPlan
  for each file and path
    0. read mtimes
    1. compile
    2. verify that file has NOT changed (always)
    3. modify a file
    4. compile
    5. verify that app file has changed (if it should)

   do above for cases:
    with libs, without libs
    with libsOnlyTarget, without libsOnlyTarget
  */
  var testCount = 0;
  for (var k = 0; k < 3; k += 1) {
    testCount += runCase(k);
  }
  // should take 6 * 2 + 1 * 4 = 16s
  console.log('compile#modified - completed:', testCount);
};
