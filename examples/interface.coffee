brownie = require 'brownie'
dir = __dirname
brownie.bake
  namespace   : 'QQ'
  target      : './output.js'
  domains     : [
    ['client',  dir+'/app_code/']
    ['shared',  dir+'/shared_code/']
  ]
  treeTarget  : './treetarget.txt'
  DOMLoadWrap : (code) -> code

###
couple of points here
1. basePoint not defined => brownie will look for 'app.coffee' in the 'client' domain
2. using DOMLoadWrap as identity function here because I dont need jQuery or the DOM in this example - this simply avoids the extra wrapping
3. running this script to regenerate the two target files, then see the effects with test.html
###


