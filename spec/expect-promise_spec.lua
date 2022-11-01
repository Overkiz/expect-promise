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

  before_each('create tested promise', function()
    promise = Promise(function(resolve)
      local timer = ev.Timer.new(resolve, ASYNC_LENGTH)
      timer:start(loop)
    end):thenCall(function()
      return 42
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
      end,  'expected %(number%) 42 to not equal %(number%) 42')

      case('resove promise and succeed if assertion succeeds', function()
        return expect(promise).to.eventually.Not.equal(12)
      end)
    end)
  end)
end)
