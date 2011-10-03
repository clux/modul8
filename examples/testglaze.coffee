brownie = require 'brownie'
dir = __dirname
brownie.glaze
  entryPoint  : dir+'/styles/main.styl'
  target      : './output.css'
  #nibs        : path + '/app/client/styles/nibs/'
  minify      : false
