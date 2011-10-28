fs      = require 'fs'
md      = require("node-markdown").Markdown
path    = __dirname

files = ['api', 'cli', 'commonjs', 'modularity', 'require']

task 'docs', 'build docs', (opts) ->
  head = fs.readFileSync('head.html', 'utf8')
  tail = fs.readFileSync('tail.html', 'utf8')
  for file in files
    out = fs.readFileSync('../docs/'+file+'.md', 'utf8')
    fs.writeFileSync('./docs/'+file+'.html', head+md(out)+tail)

  #out = fs.readFileSync('../Readme.md', 'utf8')
  #fs.writeFileSync('./index.html', head+md(out)+tail)

  return
