var modul8  = require('../../')
  , fs      = require('fs')
  , dir     = __dirname;


modul8('main.coffee')
  .before(modul8.testcutter)
  .libraries()
    .list(['monolith.js'])
    .path(dir+'/libraries/')
    .target(dir+'/outputlibs.js')
  .arbiters()
    .add('monolith')
  .domains()
    .add('app', dir+'/app_code/')
    .add('shared', dir+'/shared_code/')
  .analysis()
    .output(console.log)
    .prefix(true)
  .data()
    .add('test', function(){
      return fs.readFileSync(__dirname+'/data.json', 'utf8');
    })
  .set('namespace', 'QQ')
  .set('domloader', false)
  .compile('./output.js');

// Alternatively use the CLI (for the app code):
// $ modul8 app_code/main.coffee -p shared:shared_code/ -a monolith  -tln QQ -d test:data.json > output.js

// same call with replacing '> output.js' with '-z' to get the analysis

