brownie = require 'brownie'
dir = __dirname
brownie.bake
  namespace   : 'QQ'
  target      : './output.js'
  domains     :
    app         :  dir+'/app_code/'
    shared      :  dir+'/shared_code/'
  treeTarget  : './treetarget.txt'
  DOMLoadWrap : (code) -> "(function(){"+code+"})();"
  minifier    : (code) -> code.replace(/\n/,'')
  minify      : true
  domPrefix   : true
  localTests  : true # app::helper has inlined tests

# NB: basePoint and mainDomain not defined here
# => brownie will look for 'main.coffee' in the 'app' domain.

# To regenerate output, just run this script

