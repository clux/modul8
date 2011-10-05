fs     = require 'fs'
coffee = require 'coffee-script'

task '8', 'build modul8', (opts) ->
  for name in ['bundle', 'analysis', 'utils']
    fs.writeFileSync 'lib/'+name+'.js', coffee.compile(fs.readFileSync('src/'+name+'.coffee', 'utf8'))
  fs.writeFileSync 'lib/require.coffee', fs.readFileSync('src/require.coffee', 'utf8')
