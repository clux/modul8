zombie = require 'zombie'
assert = require 'assert'
fs = require 'fs'
rimraf = require 'rimraf'
utils = require '../lib/utils' #hook in to this
modul8 = require '../' #public interface
dir = __dirname


data =
  a : "hello thar"
  b : {coolObj:{}}
  c : 5
  d : [2, 3, "abc", {'wee':[]}]
  e : 9 + 'abc'


generateApp = (options)-> # dont call this with size < 4 otherwise we wont get the mixins

  # clean out old directory
  try rimraf.sync(dir+'/input')
  catch e
  fs.mkdirSync(dir+'/input', 0755)
  fs.mkdirSync(dir+'/input/main', 0755)

  fs.writeFileSync(dir+'/input/main/temp.js', "") # write blank entry point

  modul8(dir+'/input/main/temp.js')
    .set('force', true)
    .set('namespace', 'QQ')
    .set('logging', false)
    #.analysis().output(console.log)
    .data(data)
      .add('crazy1', -> new Date())
      .add('crazy2', 'new Date()', true)
      .add('crazy3', -> window)
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

    assert.ok(browser.evaluate("QQ.require('data::crazy1')"), "require('data::crazy1') exists")
    assert.ok(browser.evaluate("QQ.require('data::crazy2')"), "require('data::crazy2') exists")
    assert.ok(browser.evaluate("QQ.require('data::crazy3')"), "require('data::crazy3') exists")

    assert.ok(browser.evaluate("QQ.require('data::crazy1').getDay"), "require('data::crazy1') is an instance of Date")
    assert.ok(browser.evaluate("QQ.require('data::crazy2').getDay"), "require('data::crazy2') is an instance of Date")
    assert.ok(browser.evaluate("QQ.require('data::crazy3').QQ"), "require('data::crazy3') returns window (found namespace)")

    testCount = 9

    for key of data
      #creating data
      assert.ok(browser.evaluate("QQ.require('data::#{key}')"), "require('data::#{key}') exists")
      assert.eql(browser.evaluate("QQ.require('data::#{key}')"), data[key], "require('data::#{key}') is data[#{key}]")
      browser.evaluate("var dataMod = QQ.data;")

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
