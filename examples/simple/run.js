var modul8 = require('./../../index.js');
var dir = __dirname;

modul8('app.js')
  .domains()
    .add('app', dir+'/app_code/')
  .arbiters()
    .add('jQuery', ['jQuery','$'])
  .analysis()
    .output(console.log)
  .compile('./output.js');

