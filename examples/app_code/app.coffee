# require calls not starting with './' will scan all the require paths
# it will always look on the path you require from first (client here)
helper = require 'helper.coffee'

helper('hello from app via helper')

b = require('bigthing/sub1.coffee')

b.doComplex('app calls up to sub1')

v = require 'validation.coffee' # wont be found on clients require path
# it will be found on the shared path

console.log 'Leap Years'
console.log '2000?', v.isLeapYear(2000)
console.log '2001?', v.isLeapYear(2001)
console.log '2002?', v.isLeapYear(2002)
console.log '2003?', v.isLeapYear(2003)
console.log '2004?', v.isLeapYear(2004)
console.log '2100?', v.isLeapYear(2100)
