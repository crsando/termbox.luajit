package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

local Layout = require("tui.layout")

local fixed = Layout.vertical({
    Layout.fixed("first", 2),
    Layout.fixed("second", 3),
}):split({ width = 10, height = 10 })

assert(fixed.first.y == 0)
assert(fixed.first.height == 2)
assert(fixed.second.y == 2)
assert(fixed.second.height == 3)

local mixed = Layout.vertical({
    Layout.flex("first", 1),
    Layout.flex("second", 1),
    Layout.fixed("footer", 3),
}):split({ width = 10, height = 10 })

assert(mixed.first.height == 3)
assert(mixed.second.height == 4)
assert(mixed.footer.height == 3)
assert(mixed.footer.y == 7)

local overflow = Layout.vertical({
    Layout.fixed("first", 8),
    Layout.fixed("second", 8),
    Layout.flex("rest", 1),
}):split({ width = 10, height = 10 })

assert(overflow.first.y == 0)
assert(overflow.first.height == 8)
assert(overflow.second.y == 8)
assert(overflow.second.height == 2)
assert(overflow.rest.y == 10)
assert(overflow.rest.height == 0)

local horizontal = Layout.horizontal({
    Layout.fixed("left", 2),
    Layout.flex("middle", 1),
    Layout.fixed("right", 3),
}):split({ x = 1, y = 2, width = 10, height = 4 })

assert(horizontal.left.x == 1)
assert(horizontal.left.width == 2)
assert(horizontal.middle.x == 3)
assert(horizontal.middle.width == 5)
assert(horizontal.right.x == 8)
assert(horizontal.right.width == 3)

local negative_origin = Layout.horizontal({
    Layout.flex("content"),
}):split({ x = -2, y = -1, width = 3, height = 2 })
assert(negative_origin.content.x == -2)
assert(negative_origin.content.y == -1)
assert(negative_origin.content.width == 3)

assert(not pcall(Layout.fixed, "invalid", -1))
assert(not pcall(Layout.flex, "invalid", 0))
assert(not pcall(Layout.flex, "invalid", false))
assert(not pcall(function()
    Layout.vertical({ Layout.flex("content") }):split(false)
end))
assert(not pcall(function()
    Layout.vertical({ Layout.flex("content") }):split({ width = false })
end))
assert(not pcall(function()
    Layout.vertical({
        Layout.flex("duplicate"),
        Layout.flex("duplicate"),
    }):split({ width = 1, height = 1 })
end))

print("layout: ok")
