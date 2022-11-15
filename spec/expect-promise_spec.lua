local Promise = require('promise')
local expect = require('expect')
local ev = require('ev')

local loop = ev.Loop.default
local ASYNC_LENGTH = 0.01 -- 10ms

local function case(testName, testFunction, expectedError)
  it('should ' .. testName, function()
    local success = false
    local errorMessage
    local ok, result = pcall(testFunction)
    if ok then
      expect(result and result.thenCall, 'function should return a promise').to.be.a('function')
      result:thenCall(function()
        success = true
      end, function(msg)
        errorMessage = msg
      end)
    else
      errorMessage = result
    end
    loop:loop()
    if expectedError then
      expect(success).to.be.False()
      expect(errorMessage).to.match(expectedError)
    else
      expect(success, tostring(errorMessage)).to.be.True()
    end
  end)
end

describe('expect-promise', function()
  local promise
  local failedPromise

  before_each('create tested promise', function()
    promise = Promise(function(resolve)
      local timer = ev.Timer.new(resolve, ASYNC_LENGTH)
      timer:start(loop)
    end):thenCall(function()
      return 42
    end)
    failedPromise = Promise(function(resolve)
      local timer = ev.Timer.new(resolve, ASYNC_LENGTH)
      timer:start(loop)
    end):thenCall(function()
      return Promise.reject('Reject')
    end)
  end)

  case('pass if target is immediately resolved', function()
    return expect(Promise.resolve(12)).to.eventually.equal(12)
  end)

  case('fail if target is not a promise', function()
    return expect(12).to.eventually.equal(12)
  end, 'expected %(number%) 12 to be a promise')

  case('fail if target is actually a simple table', function()
    return expect({}).to.eventually.deep.equal({})
  end, 'expected %(table.* to be a promise')

  describe('eventually', function()
    describe('(positive)', function()
      case('resove promise and succeed if assertion succeeds', function()
        return expect(promise).to.eventually.be.a('number').that.equals(42)
      end)

      case('resove promise and fail if assertion fails', function()
        return expect(promise).to.eventually.equal(12)
      end, 'expected %(number%) 42 to equal %(number%) 12')
    end)

    describe('(negative)', function()
      case('resove promise and fail if assertion fails', function()
        return expect(promise).to.Not.eventually.equals(42)
      end, 'expected %(number%) 42 to not equal %(number%) 42')

      case('resove promise and succeed if assertion succeeds', function()
        return expect(promise).to.eventually.Not.equal(12)
      end)
    end)
  end)

  describe('fulfilled', function()
    describe('(positive)', function()
      case('succeed if promise is fulfilled', function()
        return expect(promise).to.be.fulfilled()
      end)

      case('fail if promise is rejected', function()
        return expect(failedPromise).to.be.fulfilled()
      end, 'expected promise %(table.* to be fulfilled but it was rejected with %(string%) \'Reject\'$')
    end)

    describe('(negative)', function()
      case('fail if promise is fulfilled', function()
        return expect(promise).Not.to.be.fulfilled()
      end, 'expected promise %(table.* to be rejected but it was fulfilled with %(number%) 42$')

      case('succeed if promise is rejected', function()
        return expect(failedPromise).Not.to.be.fulfilled()
      end)
    end)
  end)

  describe('rejected', function()
    describe('(positive)', function()
      case('succeed if promise is rejected', function()
        return expect(failedPromise).to.be.rejected()
      end)

      case('fail if promise is fulfilled', function()
        return expect(promise).to.be.rejected()
      end, 'expected promise %(table.* to be rejected but it was fulfilled with %(number%) 42$')
    end)

    describe('(negative)', function()
      case('fail if promise is rejected', function()
        return expect(failedPromise).Not.to.be.rejected()
      end, 'expected promise %(table.* to be fulfilled but it was rejected with %(string%) \'Reject\'$')

      case('succeed if promise is fulfilled', function()
        return expect(promise).Not.to.be.rejected()
      end)
    end)
  end)

  describe('rejectedWith', function()
    describe('(positive)', function()
      case('succeed if promise is rejected with matching error', function()
        return expect(failedPromise).to.be.rejectedWith('.*ject$')
      end)

      case('succeed if promise is rejected with exact error', function()
        return expect(failedPromise).to.be.rejectedWith('Reject', true)
      end)

      case('succeed if promise is rejected with expected number as string', function()
        return expect(Promise.reject('12')).to.be.rejectedWith(12)
      end)

      case('succeed if promise is rejected with expected number', function()
        return expect(Promise.reject(12)).to.be.rejectedWith(12)
      end)

      case('succeed if promise is rejected with expected table', function()
        return expect(Promise.reject({
          'item1',
          key = 'value1'
        })).to.be.rejectedWith({
          'item1',
          key = 'value1'
        })
      end)

      case('fail if promise is fulfilled', function()
        return expect(promise).to.be.rejectedWith('any error')
      end, 'expected promise %(table.* to be rejected with %(string%) \'any error\' but it was fulfilled$')

      case('fail if promise is rejected with non matching error', function()
        return expect(failedPromise).to.be.rejectedWith('Fulfilled')
      end,
        'expected promise %(table.* to be rejected with %(string%) \'Fulfilled\' but it was rejected with %(string%) \'Reject\'$')

      case('fail if promise is rejected with wrong error', function()
        return expect(failedPromise).to.be.rejectedWith('.*ject', true)
      end,
        'expected promise %(table.* to be rejected with %(string%) \'.*ject\' but it was rejected with %(string%) \'Reject\'$')

      case('fail if promise is rejected with wrong number as string', function()
        return expect(Promise.reject('12')).to.be.rejectedWith(144)
      end, 'expected promise %(table.* to be rejected with %(number%) 144 but it was rejected with %(string%) \'12\'$')

      case('fail if promise is rejected with wrong number', function()
        return expect(Promise.reject(12)).to.be.rejectedWith(144)
      end, 'expected promise %(table.* to be rejected with %(number%) 144 but it was rejected with %(number%) 12')

      case('fail if promise is rejected with wrong table', function()
        return expect(Promise.reject({
          'This should fail',
          failure = true
        })).to.be.rejectedWith({
          'This should fail',
          failure = false
        })
      end, 'expected promise %(table.* to be rejected with %(table.* but it was rejected with %(table')
    end)

    describe('(negative)', function()
      case('succeed if promise is fulfilled', function()
        return expect(promise).to.Not.be.rejectedWith('any error')
      end)

      case('succeed if promise is rejected with non matching error', function()
        return expect(failedPromise).to.Not.be.rejectedWith('Fulfilled')
      end)

      case('fail if promise is rejected with matching error', function()
        return expect(failedPromise).to.Not.be.rejectedWith('Reject')
      end, 'expected promise %(table.* not to be rejected with %(string%) \'Reject\'$')
    end)
  end)
end)
