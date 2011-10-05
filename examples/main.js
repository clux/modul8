var modul8 = require('./../index.js');
var dir = __dirname;

homebrewMinifier = function(code){
  return code.replace(/\n/,'');
};

domLoader = function(code){
  return "(function(){"+code+"})();";
};

modul8('main.coffee')
  .libraries()
    .list(['monolith.js'])
    .path(dir+'/libraries/')
  .domains()
    .add('app', dir+'/app_code/')
    .add('shared', dir+'/shared_code/')
  .analysis()
    .output('./treetarget.txt')
    .prefix(true)
  .set('namespace', 'QQ')
  .set('domloader', domLoader)
  .pre(modul8.testcutter)
  .post(homebrewMinifier)
  .compile('./output.js');

