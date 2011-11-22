var modul8 = require('../../');

modul8('./app_code/app.js')
  .arbiters()
    .add('jQuery', ['jQuery','$'])
  .analysis(console.log)
  .set('domloader', 'jQuery')
  .set('force', true)
  .compile('./output.js');

// alternatively use the CLI:
// $ modul8 app_code/app.js -a jQuery=jQuery,$ -w jQuery > output.js
