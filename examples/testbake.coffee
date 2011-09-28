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
  DOMLoadWrap : (code) -> "(function(){"+code+"})();" # wont actually hold off for DOMContent, but this is how you would write a wrapper function
  minifier    : (code) -> code.replace(/\n/,'')       # my minifier is better than yours
  minify      : true

###
Notes
1. basePoint not defined => brownie will look for 'app.coffee' in the 'client' domain
2. If you do not want your app to wait for DOMContent, you could pass in the identity function and wrap your relevant bits of code yourself.
3. My minifier is abysmal, but it is just an API example..
4. To generate this examples output (if you modified it, just run this script: coffee testbake.coffe [or compile it to javascript first and node testbake.js])
###


