local Expect = require('expect.Expect')
local FailureMessage = require('expect.FailureMessage')
local Utils = require("expect.Utils")

-- Compatibility trick
local unpack = unpack or table.unpack

return function(expect)
  local function promiseNext(promise, next)
    local fnName = (expect.parameters.promise and expect.parameters.promise.next) or 'next'
    return promise[fnName](promise, next)
  end

  local function ensurePromise(controlData)
    local fnName = (expect.parameters.promise and expect.parameters.promise.next) or 'next'
    controlData:assert(type(controlData.actual) == 'table' and Utils.isCallable(controlData.actual[fnName]),
      FailureMessage('expected {#} to be a promise'), nil, 2)
  end

  -- An Expect-like object resolving promise before executing the rest
  local AsyncExpect = setmetatable({}, {
    __call = function(AsyncExpect, promise)
      local initialMeta = getmetatable(promise) or {}
      local initialIndex = initialMeta.__index

      initialMeta.__index = function(_, key)
        -- Look if initial object already has an answer
        local initialObject
        if type(initialIndex) == 'function' then
          initialObject = initialIndex(promise, key)
        elseif initialIndex then
          initialObject = initialIndex[key]
        end

        -- Either use initial object or resolve and call assertion chain
        if initialObject then
          return initialObject
        else
          return AsyncExpect(promiseNext(promise, function(innerExpect)
            return innerExpect[key]
          end))
        end
      end

      initialMeta.__call = function(_, ...)
        local parameters = {...}
        return AsyncExpect(promiseNext(promise, function(innerExpect)
          return innerExpect(unpack(parameters))
        end))
      end

      return setmetatable(promise, initialMeta)
    end
  })

  -- Resolve and continue
  expect.addProperty('eventually', function(controlData)
    ensurePromise(controlData)
    return AsyncExpect(promiseNext(controlData.actual, function(value)
      controlData.actual = value
      return Expect(controlData)
    end))
  end)
end
