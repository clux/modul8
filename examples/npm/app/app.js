var backbone  = require('npm::backbone')
  , _         = require('npm::underscore')
  , events    = require('npm::events');

alert('found backbone ' + backbone.VERSION + ', and underscore: ' + _.VERSION + ', and EventEmitter? ' + !!events.EventEmitter);


