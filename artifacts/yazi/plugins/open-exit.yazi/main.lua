-- Enter uses the same default openers as `open`, but the detached launcher
-- owns every launch before it asks Yazi to exit.
local snapshot = ya.sync(function()
  local targets = {}
  for _, file in pairs(cx.active.selected) do
    targets[#targets + 1] = { url = tostring(file.url), directory = file.cha.is_dir }
  end
  if #targets == 0 then
    local file = cx.active.current.hovered
    if file then
      targets[1] = { url = tostring(file.url), directory = file.cha.is_dir, mime = file:mime() }
    end
  end
  return tostring(cx.active.current.cwd), targets, rt.args.chooser_file ~= nil
end)

local resolve = ya.sync(function(_, url, mime)
  local file = cx.active.current.hovered
  if not file or tostring(file.url) ~= tostring(url) then
    file = nil
    for _, selected in pairs(cx.active.selected) do
      if tostring(selected.url) == tostring(url) then
        file = selected
        break
      end
    end
  end
  if not file then return end
  for _, rule in pairs(rt.open.rules:match { file = file, mime = mime }) do
    for _, name in ipairs(rule.use) do
      local openers = rt.opener[name]
      if openers then
        for _, opener in pairs(openers:match()) do
          return { run = opener.run, block = opener.block, orphan = opener.orphan }
        end
      end
    end
    return
  end
end)

local function fail(message)
  ya.notify { title = "Open and exit", content = message, level = "error", timeout = 8 }
end

local function expand(run, urls)
  -- Protect literal percent signs before expanding Yazi's path placeholders.
  run = run:gsub("%%%%", "\1")
  run = run:gsub("%%([sSdD])(%d*)", function(kind, index)
    local paths = {}
    local first = index == "" and 1 or tonumber(index)
    local last = index == "" and #urls or first
    for i = first, last do
      local url = urls[i]
      local path = url and tostring((kind == "d" or kind == "D") and Url(url):parent() or url) or ""
      paths[#paths + 1] = ya.quote(path)
    end
    return table.concat(paths, " ")
  end)
  return run:gsub("\1", "%%")
end

return {
  entry = function()
    local cwd, targets, chooser = snapshot()
    if chooser then
      ya.emit("open", {})
      return
    end
    if #targets == 0 then return end

    local groups, order = {}, {}
    for _, target in ipairs(targets) do
      local mime = target.directory and "folder/directory" or target.mime
      if not mime then
        local output, err = Command("file"):arg { "-bL", "--mime-type", "--", tostring(target.url) }:output()
        if not output or not output.status.success then
          fail("Cannot identify " .. tostring(target.url) .. ": " .. tostring(err or "file failed"))
          return
        end
        mime = output.stdout:gsub("%s+$", "")
      end
      local opener = resolve(target.url, mime)
      if not opener then
        fail("No opener for " .. tostring(target.url))
        return
      end
      local key = opener.run .. tostring(opener.block) .. tostring(opener.orphan)
      if not groups[key] then
        groups[key] = { opener = opener, urls = {} }
        order[#order + 1] = groups[key]
      end
      local urls = groups[key].urls
      urls[#urls + 1] = target.url
    end

    local commands, blocking = {}, false
    for _, group in ipairs(order) do
      local opener = group.opener
      local program = opener.run:match("^%s*([^%s;]+)")
      local status = Command("sh"):arg { "-c", "command -v " .. ya.quote(program) .. " >/dev/null" }:status()
      if not status or not status.success then
        fail("Cannot find " .. program .. ". Yazi will stay open.")
        return
      end
      -- Commands without a spread placeholder run once per selected file.
      local batches = opener.run:find("%%[sSdD][^%d]") or opener.run:match("%%[sSdD]$")
      local count = batches and 1 or #group.urls
      for i = 1, count do
        local urls = batches and group.urls or { group.urls[i] }
        local run = expand(opener.run, urls)
        if opener.orphan then
          commands[#commands + 1] = "setsid sh -c " .. ya.quote(run) .. " </dev/null >/dev/null 2>&1 &"
        else
          commands[#commands + 1] = "sh -c " .. ya.quote(run) .. " || exit $?"
          blocking = true
        end
      end
    end
    commands[#commands + 1] = "ya emit quit"
    -- `shell` expands placeholders again, so escape all literal percent signs.
    local run = table.concat(commands, "\n"):gsub("%%", "%%%%")
    ya.emit("shell", { run, cwd = Url(cwd), orphan = true, block = blocking })
  end,
}
