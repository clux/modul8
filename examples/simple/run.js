var modul8 = require('./../../index.js');
var dir = __dirname;

modul8('app.js')
  .domains()
    .add('app', dir+'/app_code/')
  .arbiters()
    .add('jQuery', ['$','jQuery'])
  .analysis()
    .output(console.log)
  .set('domloader', 'jQuery')
  .compile('./output.js');

// alternatively use the CLI:
// $ modul8 app_code/app.js -a jQuery:$.jQuery -w jQuery > output.js
