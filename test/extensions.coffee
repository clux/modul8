zombie = require 'zombie'
assert = require 'assert'
fs = require 'fs'
rimraf = require 'rimraf'
utils = require './../src/utils' #hook in to this
modul8 = require './../index.js' #public interface
dir = __dirname


dataObj =
  a : "hello thar"
  b : {coolObj:{}}
  c : 5
  d : [2, 3, "abc", {'wee':[]}]
  e : 9+'abc'

data = {}
for key of dataObj
  ((k) ->
    data[k] = -> JSON.stringify(dataObj[k])
  )(key)



generateApp = (options)-> # dont call this with size < 4 otherwise we wont get the mixins

  # clean out old directory
  try rimraf.sync(dir+'/input')
  catch e
  fs.mkdirSync(dir+'/input', 0755)
  fs.mkdirSync(dir+'/input/main', 0755)

  fs.writeFileSync(dir+'/input/main/temp.js', "") # write blank entry point

  modul8('temp.js')
    .set('domloader', (a) -> (a)) # dont test jQuery functionality here
    .set('namespace', 'QQ')
    #.analysis().output(console.log)
    .domains()
      .add('app', dir+'/input/main/')
    .data(data)
    .compile(dir+'/output/flat.js')


exports["test require#extensions"] = ->
  generateApp()
  compile = utils.makeCompiler()
  browser = new zombie.Browser()
  browser.visit 'file:///'+dir+"/output/empty.html", (err, browser, status) ->
    throw err if err
    mainCode = compile(dir+'/output/flat.js')

    assert.isUndefined(browser.evaluate(mainCode), ".compile() result evaluates successfully") # will throw if it fails
    assert.isDefined(browser.evaluate("QQ"), "global namespace is defined")
    assert.isDefined(browser.evaluate("QQ.require"), "require is globally accessible")
    assert.type(browser.evaluate("QQ.require"), 'function', "require is a function")

    testCount = 4

    for key of data
      #creating data
      assert.ok(browser.evaluate("QQ.require('data::#{key}')"), "require('data::#{key}') exists")
      assert.eql(browser.evaluate("QQ.require('data::#{key}')"), dataObj[key], "require('data::#{key}') is dataObj[#{key}]")
      browser.evaluate("var dataMod = QQ.require('M8::data')")

      #editing data
      assert.type(browser.evaluate("dataMod"), 'function', "M8::data is a requirable function")
      browser.evaluate("dataMod('#{key}','hello')")
      assert.equal(browser.evaluate("QQ.require('data::#{key}')"), 'hello',  "can call data overriding method on data::#{key}")
      testCount += 4

      #deleting data
      browser.evaluate("dataMod('#{key}')")
      assert.equal(browser.evaluate("QQ.require('data::#{key}')"), null, "successfully deleted data::#{key}")

    console.log 'require#extensions - completed:', testCount
  return
