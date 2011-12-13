var modul8 = require('../../');

modul8('./app/app.js')
  .analysis(console.log)
  .npm('./node_modules')
  .compile('./output.js');

// requires npm install backbone in this folder first

// alternatively use the CLI:
// $ modul8 app/app.js > output.js
