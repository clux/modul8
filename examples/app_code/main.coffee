helper = require('./helper')
# relative require looks only in this domain

helper('hello from app via helper')

b = require('bigthing/sub1')

b.doComplex('app calls up to sub1')


v = require('validation.coffee')
# wont be found on clients require path
# but will be found on the shared path

console.log('2004 isLeapYear?', v.isLeapYear(2004))


#m = window.monolith; # external libraries would be available as before
m = require('monolith') # but we added an explicit arbiter for this library, so the global variable has been deleted
console.log "monolith:",m
