var modul8 = require('./../index.js');
var dir = __dirname;

homebrewMinifier = function(code){
  return code.replace(/\n/,'');
};

domLoader = function(code){
  return "(function(){"+code+"})();";
};

modul8('main.coffee')
  .before(modul8.testcutter)
  .after(homebrewMinifier)
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
  .compile('./output.js');

