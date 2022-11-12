local DiffTable = require('expect.DiffTable')
local Expect = require('expect.Expect')
local FailureMessage = require('expect.FailureMessage')
local Utils = require('expect.Utils')

-- Compatibility trick
local unpack = unpack or table.unpack

return function(expect)
  local function promiseNext(promise, next, fail)
    local fnName = (expect.parameters.promise and expect.parameters.promise.next) or 'next'
    return promise[fnName](promise, next, fail)
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

  local function testPromiseResult(controlData, testResult)
    ensurePromise(controlData)
    return AsyncExpect(promiseNext(promiseNext(controlData.actual, function(value)
      return {
        success = true,
        result = value
      }
    end, function(reason)
      return {
        success = false,
        result = reason
      }
    end), function(result)
      testResult(result)
      return Expect(controlData)
    end))
  end

  -- Ensure promise is fulfilled
  expect.addMethod('fulfilled', function(controlData)
    return testPromiseResult(controlData, function(result)
      controlData:assert(result.success, FailureMessage(
        'expected promise {#} to be fulfilled but it was rejected with {result}', result), FailureMessage(
        'expected promise {#} to be rejected but it was fulfilled with {result}', result))
    end)
  end)

  -- Ensure promise is rejected
  expect.addMethod('rejected', function(controlData)
    return testPromiseResult(controlData, function(result)
      controlData:assert(not result.success, FailureMessage(
        'expected promise {#} to be rejected but it was fulfilled with {result}', result), FailureMessage(
        'expected promise {#} to be fulfilled but it was rejected with {result}', result))
    end)
  end)

  -- Ensure promise is rejected with error
  expect.addMethod('rejectedWith', function(controlData, expectedErr, plain)
    return testPromiseResult(controlData, function(result)
      if not result.success and type(result.result) == 'string' then
        result.result = result.result:gsub('^.-:%d+: ', '', 1)
      end
      local params = {
        expectedErr = expectedErr,
        actualErr = result.result
      }
      local testResult

      if result.success then
        if not controlData.negate then
          controlData:fail(FailureMessage(
            'expected promise {#} to be rejected with {expectedErr} but it was fulfilled', params))
        end
      elseif type(expectedErr) == 'string' and
        (type(result.result) == 'string' or type((getmetatable(result.result) or {}).__tostring) == 'function') then
        testResult = tostring(result.result):find(expectedErr, 1, plain) ~= nil
      elseif type(expectedErr) == 'number' and type(result.result) == 'string' then
        testResult = expectedErr == tonumber(result.result)
      else
        local same, expectedErr, actualErr = DiffTable.compare(expectedErr, result.result)
        testResult = same
        params = {
          expectedErr = expectedErr,
          actualErr = actualErr
        }
      end

      if testResult ~= nil then
        controlData:assert(testResult, FailureMessage(
          'expected promise {#} to be rejected with {expectedErr} but it was rejected with {actualErr}', params),
          FailureMessage('expected promise {#} not to be rejected with {expectedErr}', params))
      end
    end)
  end)
end
