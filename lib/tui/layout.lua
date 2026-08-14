local Layout = {}

local function check_integer(value, name, minimum, level)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge
        or value ~= math.floor(value)
        or (minimum ~= nil and value < minimum)
    then
        local requirement = minimum ~= nil
            and " an integer >= " .. minimum
            or " a finite integer"
        error(name .. " must be" .. requirement, level or 3)
    end

    return value
end

local function check_weight(value, level)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge
        or value <= 0
    then
        error("flex weight must be a finite number > 0", level or 3)
    end

    return value
end

local function normalize_rect(rect)
    if rect ~= nil and type(rect) ~= "table" then
        error("rect must be a table", 3)
    end

    rect = rect or {}
    local x = rect.x == nil and 0 or rect.x
    local y = rect.y == nil and 0 or rect.y
    local width = rect.width == nil and 0 or rect.width
    local height = rect.height == nil and 0 or rect.height

    return {
        x = check_integer(x, "rect.x", nil, 4),
        y = check_integer(y, "rect.y", nil, 4),
        width = check_integer(width, "rect.width", 0, 4),
        height = check_integer(height, "rect.height", 0, 4),
    }
end

local function new_layout(direction, items)
    if type(items) ~= "table" then
        error("layout items must be a table", 3)
    end

    return {
        direction = direction,
        items = items,

        split = function(self, rect)
            rect = normalize_rect(rect)

            local fixed = 0
            local flex = 0
            local variable = {}
            local last_flex
            local ids = {}

            for index, item in ipairs(self.items) do
                if type(item) ~= "table" then
                    error("layout item must be a table", 2)
                end

                if item.id ~= nil then
                    if ids[item.id] then
                        error("duplicate layout item id: " .. tostring(item.id), 2)
                    end

                    ids[item.id] = true
                end

                if item.fixed ~= nil then
                    fixed = fixed + check_integer(
                        item.fixed,
                        "fixed size",
                        0,
                        4
                    )
                else
                    local raw_weight = item.flex == nil and 1 or item.flex
                    local weight = check_weight(raw_weight, 4)

                    flex = flex + weight
                    variable[index] = weight
                    last_flex = index
                end
            end

            local available = self.direction == "vertical"
                and rect.height
                or rect.width
            local remaining = math.max(0, available - fixed)
            local result = {}
            local offset = 0
            local allocated_flex = 0
            local sizes = {}

            for index, item in ipairs(self.items) do
                if item.fixed ~= nil then
                    sizes[index] = item.fixed
                elseif index == last_flex then
                    sizes[index] = remaining - allocated_flex
                else
                    sizes[index] = math.floor(remaining * variable[index] / flex)
                    allocated_flex = allocated_flex + sizes[index]
                end
            end

            for index, item in ipairs(self.items) do
                local size = math.min(sizes[index], math.max(0, available - offset))

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
        fixed = check_integer(size, "fixed size", 0, 3),
    }
end

function Layout.flex(id, weight)
    weight = weight == nil and 1 or weight

    return {
        id = id,
        flex = check_weight(weight, 3),
    }
end

return Layout
