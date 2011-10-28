var modul8  = require('../../')
  , fs      = require('fs')
  , dir     = __dirname;


modul8('main.coffee')
  .before(modul8.testcutter)
  .libraries()
    .list(['monolith.js'])
    .path(dir+'/libraries/')
  .arbiters()
    .add('monolith')
  .domains()
    .add('app', dir+'/app_code/')
    .add('shared', dir+'/shared_code/')
  .analysis()
    .output(console.log)
    .prefix(true)
  .data({'test': function(){
    return fs.readFileSync(__dirname+'/data.json', 'utf8');
  }})
  .set('namespace', 'QQ')
  .set('domloader', false) // dont make app wait for the DOM to load
  .compile('./output.js');

// CLI code for this would be:
// $ modul8 app_code/main.coffee -p shared:shared_code/ -a monolith  -tln QQ -d test:data.json

// same call with -z to get the analysis

