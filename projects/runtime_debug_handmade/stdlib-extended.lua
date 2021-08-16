--[[
  Reduce a list starting from an initial element, and combining elements using a specific function.

  Example: `table.reduce({1, 2, 3, 4}, function (x, y) return x + y end, 0)` is equivalent to:
  - `table.reduce({2, 3, 4}, function (x, y) return x + y end, 0 + 1)`
  - `table.reduce({3, 4}, function (x, y) return x + y end, 0 + 1 + 2)`
  - `table.reduce({4}, function (x, y) return x + y end, 0 + 1 + 2 + 3)`
  - `0 + 1 + 2 + 3 + 4`
  - `10`

  Borrowed from: https://stackoverflow.com/a/8695525/6718698
]]
table.reduce = function(list, fn, init)
  local acc = init
  for k, v in ipairs(list) do
    if 1 == k and not init then
      acc = v
    else
      acc = fn(acc, v)
    end
  end
  return acc
end

sum = function(list)
  return table.reduce(list, function(x, y) return x + y end, 0)
end

--[[
  Round the argument to the nearest integer
]]
math.round = function(i)
  return math.floor(i + 0.5)
end

--[[
  Round `n` to the upper nearest multiple of `k`
]]
math.roundup = function(n, k)
  -- Algorithm adapted to Lua from: https://stackoverflow.com/a/3407254/6718698
  if k == 0 then
    return n
  end

  local rem = math.abs(n) % k
  if rem == 0 then
    return n
  end

  if n < 0 then
    return -(math.abs(n) - rem)
  else
    return n + k - rem
  end
end
