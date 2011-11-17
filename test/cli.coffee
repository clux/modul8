zombie = require 'zombie'
assert = require 'assert'
fs = require 'fs'
rimraf = require 'rimraf'
utils = require '../lib/utils' #hook in to this
modul8 = require '../' #public interface
cli = require '../bin/cli'
dir = __dirname

argv = [
  'coffee',
  './bin/cli.coffee',
  './examples/advanced/app_code/main.coffee',
  '-p',
  'shared=./examples/advanced/shared_code/',
  '-a',
  'monolith',
  '-tn',
  'QQ',
  '-d',
  'test=./examples/advanced/data.json'
  '-z'
]

exports["test CLI"] = ->
  testCount = 0
  cli(argv)


  console.log 'require#plugins - completed:', testCount

  #browser = new zombie.Browser()
  #browser.visit 'file:///'+dir+"/empty.html", (err, browser, status) ->
  #  throw err if err
  #  mainCode = compile(dir+'/output/flat.js')
