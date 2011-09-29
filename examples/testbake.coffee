brownie = require 'brownie'
dir = __dirname
brownie.bake
  namespace   : 'QQ'
  target      : './output.js'
  domains     :  # basePoint.mainDomain not defined => brownie will look for 'main.coffee' in the 'app' domain
    app         :  dir+'/app_code/'
    shared      :  dir+'/shared_code/'
  treeTarget  : './treetarget.txt'
  DOMLoadWrap : (code) -> "(function(){"+code+"})();" # wont actually hold off for DOMContent, but this is how you would write a wrapper function
  minifier    : (code) -> code.replace(/\n/,'')       # can possibly be improved
  minify      : true
  domPrefix   : true


# To generate this examples output (if you modified it, just run this script: coffee testbake.coffe [or compile it to javascript first and node testbake.js])

