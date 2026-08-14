package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

assert(require("luv"))

package.loaded["tui.text"] = nil
package.loaded["lua-utf8"] = nil
package.preload["lua-utf8"] = function()
    error("simulated lua-utf8 load failure")
end

local ok, message = pcall(require, "tui.text")
assert(not ok)
assert(tostring(message):find("tui.text requires luautf8", 1, true))
assert(tostring(message):find("luarocks --lua-version=5.1", 1, true))

print("dependencies: ok")
