local BravUI = BravUI

function BravUI:LoadModules()
    for name, module in pairs(self.modules) do
        if module.Init then
            local ok, err = pcall(module.Init, module)
            if not ok then
                BravLib.Warn("Error initializing module '" .. name .. "': " .. tostring(err))
            end
        end
    end

    for name, module in pairs(self.modules) do
        if module.Enable then
            local ok, err = pcall(module.Enable, module)
            if ok then
                module.enabled = true
            else
                BravLib.Warn("Error enabling module '" .. name .. "': " .. tostring(err))
            end
        end
    end

    BravLib.Debug("All modules loaded")
end

function BravUI:DisableModule(name)
    local module = self.modules[name]
    if not module then return end
    if module.Disable then
        pcall(module.Disable, module)
    end
    module.enabled = false
end

function BravUI:EnableModule(name)
    local module = self.modules[name]
    if not module or module.enabled then return end
    if module.Enable then
        local ok, err = pcall(module.Enable, module)
        if ok then
            module.enabled = true
        else
            BravLib.Warn("Error enabling module '" .. name .. "': " .. tostring(err))
        end
    end
end
