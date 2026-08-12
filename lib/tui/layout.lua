local Layout = {}

local function normalize_rect(rect)
    return {
        x = rect.x or 0,
        y = rect.y or 0,
        width = math.max(0, rect.width or 0),
        height = math.max(0, rect.height or 0),
    }
end

local function new_layout(direction, items)
    return {
        direction = direction,
        items = items,

        split = function(self, rect)
            rect = normalize_rect(rect)

            local fixed = 0
            local flex = 0
            local variable = {}

            for index, item in ipairs(self.items) do
                local fixed_size = item.fixed or 0
                fixed = fixed + fixed_size

                if not item.fixed then
                    local weight = item.flex or 1
                    flex = flex + weight
                    variable[index] = weight
                end
            end

            local available = self.direction == "vertical"
                and rect.height
                or rect.width
            local remaining = math.max(0, available - fixed)
            local result = {}
            local offset = 0

            for index, item in ipairs(self.items) do
                local size = item.fixed or 0

                if not item.fixed then
                    size = math.floor(remaining * variable[index] / flex)
                end

                if index == #self.items then
                    size = math.max(0, available - offset)
                end

                local child

                if self.direction == "vertical" then
                    child = {
                        x = rect.x,
                        y = rect.y + offset,
                        width = rect.width,
                        height = size,
                    }
                else
                    child = {
                        x = rect.x + offset,
                        y = rect.y,
                        width = size,
                        height = rect.height,
                    }
                end

                result[item.id or index] = child
                offset = offset + size
            end

            return result
        end,
    }
end

function Layout.vertical(items)
    return new_layout("vertical", items)
end

function Layout.horizontal(items)
    return new_layout("horizontal", items)
end

function Layout.fixed(id, size)
    return {
        id = id,
        fixed = size,
    }
end

function Layout.flex(id, weight)
    return {
        id = id,
        flex = weight or 1,
    }
end

return Layout
