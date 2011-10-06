## Modularity Notes
Global variable are evil, and should be kept to a minimum. We know this, and this is were a require system really shines, but it is not going to help you get rid of global usage altogether.
However, it is possible to make yourself almost completely independent of globals!

The obvious way is to lead a life of strict CommonJS adherence, or, more sensibly, you could make arbiters for all your old libraries.
jQuery for instance, could be exported through another jQuery.js file with `module.exports = window.jQuery; delete window.jQuery; delete window.$` in its body.
This means you can use `$ = require('jQuery')` so everything will be explicitly defined, plus you've deleted the global shortcuts so that you will know when you forgot to require.

Clearly this as some advantages. By having all requires of jQuery explicitly defined you know exactly what parts of your code depend on it. It will show up in your require tree, and
you will quickly identify what code is actually DOM dependent, and what isn't or shouldn't be.

Modul8 already does some of this for you anyway, it allows at most your mainDomain to wait for the DOM. If you can figure out how to separate on the domain level, then you are already
good on your way to resolving spaghetti hell. Perhaps by having jQuery available everywhere on that domain isnt _that_ bad. Probably not, but by not having it available by default,
it is easier to see what actually needs it and what doesn't, and it becomes harder to accidentally introduce dependencies in areas that should not have them.

An extra ting to note is that jQuery plugins work generally with the global jQuery variable, so they should be normally loaded as libFiles. This ensures `require('jQuery')` gets the
fully extended version you want.

Anyway. With jQuery you have bigger modularity issues to battle with than this, for those still struggling with spaghetti hell:
#### My advice is
Think about the behaviour you are defining, if it is for

- non-request based DOM interactivity - it is almost always better to write a plugin
- request based DOM interactivity - you should use controllers/views and call above plugins.
- calculations needed for DOM manipulation - you should make a standalone calulation module that should work on its own - call it at appropriate stages above.

This way if something breaks, you should be easily able to narrow down the problem to a UI error, a signaling error, or a calculation error. => Debugging becomes up to 3 times easier.

#### Ultimately
Modul8 just tries to facilitate the building of maintainable code.
To actually build maintainable code, you need to always stay vigilant and remember to:

- Not blend multiple types of behaviour together in one file.
- Limit the areas from which you reference global variables.
- Look for opportunities to move independent code onto different domains.
- Look for opportunities to refactor code to make bits of it independent.
- Enforce basic rules of JavaScript modularity: don't try to make circular dependencies work, analyse your require tree. If you are requiring the same library from every file, chances are you are doing something wrong.

Decouple your code this way and you will save yourself the trouble of later having to learn from your mistakes the hard way.
