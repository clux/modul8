fs     = require 'fs'
coffee = require 'coffee-script'

task 'bake', 'build', (opts) ->
  for name in ['brownie', 'codeanalysis', 'utils']
    fs.writeFileSync 'lib/'+name+'.js', coffee.compile(fs.readFileSync('src/'+name+'.coffee', 'utf8'))
