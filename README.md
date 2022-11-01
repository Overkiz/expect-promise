# Expect-promise - expect package plugin for promises

The package `expect-promise` is a plugin to [expect](https://github.com/sveyret/expect) which adds words used
to manage promises.

# Installation

You can install `expect-promise` using LuaRocks with the command:

```shell
luarocks install expect-promise
```

# Compatibility

The plugin is tested against the [promise-lua](https://github.com/pyericz/promise-lua), but it may be usable
with any module providing promises, as far as it respects the [A+ specification](https://promisesaplus.com/)
(no matter how the `then` function is actually called), and the promise object has a modifiable metatable.

# Configuration

In order to use the plugin, you must declare it somewhere in your tests. A good place for this is a file
always read before executing the tests. For that, simply require the module, providing the `expect` object as
parameter.

By default, the plugin expects your promise to have a `next` method behaving like the `then` method of the
promise A+ specification. If this is not the case, you must provide the name of the function to the
configuration option `expect.parameters.promise.next`.

```lua
local expect = require('expect')
require('expect-promise')(expect)
expect.parameters.promise = {
  next = 'thenCall'
}
```

# Usage

## eventually

Resolves the promise, replaces the target object with the result, and continues the assertion chain.

```lua
expect(Promise.resolve(42)).to.eventually.be.a("number").that.equals(42)
```
