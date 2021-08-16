__DEBUG__NUMBER_OF_BUSES       = 0
__DEBUG__BUS_WIDTHS            = {}
__DEBUG__FORMATS               = {}

--[[
  Parse a C-like format and returns all the string parts and the "holes" (the formats, really)
]]
function parse_format(fmt)
  local backbone = {}
  local holes = {}

  -- format lexer
  local current_backbone = ''
  local is_format = false
  for c in fmt:gmatch(".") do
    if is_format then
      is_format = false
      if c == '%' then
        current_backbone = current_backbone .. c
        is_format = false
      elseif c == 'b' or c == 'x' then -- TODO: support more formats later, possibly never
        table.insert(backbone, current_backbone)
        current_backbone = ''
        table.insert(holes, c)
      else
        error('Invalid format "%' .. c .. '"')
      end
    else
      if c == '%' then
        is_format = true
      else
        current_backbone = current_backbone .. c
      end
    end
  end
  if is_format then
    error('Invalid format "%"')
  end

  -- NOTE: insert our current backbone in the backbone list, because it may not be empty
  --       if it is empty, it's ok because we want it
  table.insert(backbone, current_backbone)
  current_backbone = ''

  return backbone, holes
end


--[[
  Preprocessor-only debugging function for Silice, as a big proof of concept before implementing it in the compiler
]]
function __debug(alg, fmt, ...)
  local args = {...}

  if SIMULATION then
    local args_str = ''

    for _, v in ipairs(args) do
      args_str = args_str .. ', ' .. v
    end

    return '__display("' .. fmt .. '", ' .. args_str .. ')'
  else
    __DEBUG__NUMBER_OF_BUSES = __DEBUG__NUMBER_OF_BUSES + 1

    local args_str = '{'
    local N = #__DEBUG__FORMATS
    local format_parts, specifiers = parse_format(fmt)
    table.insert(__DEBUG__FORMATS, {fmts = format_parts, specs = specifiers})

    if #specifiers ~= #args then
      error('Not enough arguments to "__debug" macro: has ' .. #specifiers .. ' formats but got ' .. #args .. ' arguments')
    end

    local bus_width = {}
    for k, v in ipairs(args) do
      if k == 1 then
        args_str = args_str .. v[2]
      else
        args_str = args_str .. ', ' .. v[2]
      end
      table.insert(bus_width, v[1])
    end
    table.insert(__DEBUG__BUS_WIDTHS, bus_width)

    if sum(bus_width) > 0 then
      return alg .. '.data' .. (N + 1) .. ' = ' .. args_str .. '};'
    else
      return '// 0 formats to output'
    end
  end
end



function __debug_display_fmt(fmt)
  local disp = ''

  for c in fmt:gmatch(".") do
    if c == '\n' then
      disp = disp .. 'io.data = 8b00010000; io.set_cursor = 1; while (!io.ready) {} // Go to the next line\n'
    else
      disp = disp .. 'io.data = 8d' .. string.byte(c) .. '; io.print = 1; while (!io.ready) {} // Print the character "' .. c .. '"\n'
    end
  end

  return disp
end


function __debug_display_value(specifier, data, width)
  -- INFO: first argument in data bus is at `data$i$[widthof(data$i$)-width[$i$],width[$i$]]`
  --       second argument is at `data$i$[width[$i-1$]-width[$i$],width[$i$]]`
  --       ...
  local disp = ''
  if specifier == 'b' then
    for i = width, 1, -1 do
      disp = disp .. 'io.data = ' .. data .. '[' .. (i - 1) .. ', 1] ? 8d49 : 8d48; io.print = 1; while (!io.ready) {}\n'
    end
    return disp
  elseif specifier == 'x' then
    for i = math.roundup(width, 4) - 4, 0, -4 do
      local value = ''
      if i + 4 > width then
        local overflowing = i + 4 - width
        value = '{ ' .. overflowing .. 'b0, ' .. data .. '[' .. i .. ', ' .. (4 - overflowing) .. '] }'
      else
        value = data .. '[' .. i .. ', 4]'
      end
      disp = disp .. 'io.data = ' .. value .. ' + (' .. value .. ' > 9 ? 8d55 : 8d48); io.print = 1; while (!io.ready) {}\n'
    end
    return disp
  elseif specifier == 'd' then
    disp = disp .. '// TODO: write output formatter for signed integer ("%d")'
  else
    return '// ' .. data .. '[' .. math.round(start - width) .. ',' .. width .. ']'
  end

  return disp
end
