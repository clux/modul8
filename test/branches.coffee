zombie = require 'zombie'
assert = require 'assert'
fs = require 'fs'
utils = require './../src/utils' #hook in to this
modul8 = require './../index.js' #public interface
dir = __dirname


makeBranch1 = (num) ->
  for i in [0...num]
    l = []
    l.push "var a = "+ if i is num-1 then "{chain: true}" else "require('./#{i+1}')"+";"
    l.push "exports.chain = a.chain;"
    fs.writeFileSync(dir+'/input/app/branch1/'+i+'.js', l.join('\n'))

makeBranch2 = (num) ->
  for i in [0...num]
    l = []
    l.push "var a = "+ if i is num-1 then "{chain: true}" else "require('./#{i+1}')"+";"
    l.push "var b = "+ if Math.floor(num/2) is i then "require('./../branch1/#{i}.js')" else "{chain: true}" +";"
    l.push "var c = "+ if Math.floor(num/3) is i then "require('./../branch1/#{i}.js')" else "{chain: true}" +";"
    l.push "exports.chain = a.chain && b.chain && c.chain;"
    fs.writeFileSync(dir+'/input/app/branch2/'+i+'.js', l.join('\n'))

makeSharedBranches = (num) ->
  for i in [0...num]
    l = []
    l.push "var a = "+ if i is num-1 then "{chain: true}" else "require('./#{i+1}')"+";"
    l.push "exports.chain = a.chain;"
    fs.writeFileSync(dir+'/input/shared/'+i+'.js', l.join('\n'))

    j = []
    j.push "var a = "+ if i is num-1 then "{chain: true}" else "require('./#{i+1}')"+";"
    j.push "exports.chain = a.chain;"
    fs.writeFileSync(dir+'/input/shared/branch1/'+i+'.js', l.join('\n')) # to test priority of app domain vs shared domain

createEntry = (num, graph1, graph2) -> # can specify start points in branches
  l = []
  l.push "exports.branch1 = require('#{graph1}');"
  l.push "exports.branch2 = require('#{graph2}');"
  l.push "exports.shared = require('shared::0')"
  l.push "exports.sharedbranch1 = require('shared::branch1/0')"
  fs.writeFileSync(dir+'/input/app/entry.js', l.join('\n'))


createExampleApp = (size) ->
  #overwrite files in the branch directories (overwriting with a different size is fine!)
  makeBranch1(size)
  makeBranch2(size)
  makeSharedBranches(size)
  createEntry(size, 'branch1/0', 'branch2/0')
  modul8('entry.js')
    .set('domloader', (a) -> (a)) # dont test jQuery functionality here
    #.analysis().output(console.log)
    .domains()
      .add('app', dir+'/input/app/')
      .add('shared', dir+'/input/shared/')
    .compile(dir+'/output/output.js')


exports["test require#branches"] = ->
  num = 8
  createExampleApp(num)
  browser = new zombie.Browser()
  browser.visit 'file:///'+dir+"/output/empty.html", (err, browser, status) ->
    throw err if err
    mainCode = utils.compile(dir+'/output/output.js')

    assert.isUndefined(browser.evaluate(mainCode), ".compile() result evaluates successfully")
    assert.isDefined(browser.evaluate("M8"), "global namespace is defined")
    assert.isDefined(browser.evaluate("M8.require"), "require is globally accessible")
    assert.type(browser.evaluate("M8.require"), 'function', "require is a function")

    for i in [0...num]
      assert.isDefined(browser.evaluate("M8.require('app::branch1/#{i}')"), "require app::branch1/#{i} defined")
      assert.isDefined(browser.evaluate("M8.require('app::branch2/#{i}')"), "require app::branch2/#{i} defined")
      assert.isDefined(browser.evaluate("M8.require('shared::#{i}')"), "require shared::#{i} defined")
      assert.isDefined(browser.evaluate("M8.require('shared::branch1/#{i}')"), "require shared::branch1/#{i} defined")

    assert.ok(browser.evaluate("M8.require('entry').branch1.chain"), "entry point resolves the entire branch1 chain")
    assert.ok(browser.evaluate("M8.require('entry').branch2.chain"), "entry point resolves the entire branch2 chain")
    assert.ok(browser.evaluate("M8.require('entry').shared.chain"), "entry point resolves the entire shared base chain")
    assert.ok(browser.evaluate("M8.require('entry').sharedbranch1.chain"), "entry point resolves the entire shared branch1 chain")

    assert.includes(browser.evaluate("M8.domains()"), 'app', "domains() contain 'app'")
    assert.includes(browser.evaluate("M8.domains()"), 'app', "domains() contain 'shared'")
    assert.includes(browser.evaluate("M8.domains()"), 'app', "domains() contain 'external'")


#if module is require.main
#verifyRequireValidity()
