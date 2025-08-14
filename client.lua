local identifier = "jg-dealerfinance"

-- Wait for lb-phone resource to start
while GetResourceState("lb-phone") ~= "started" do
    Wait(500)
end
Wait(1000) -- Delay for AddCustomApp export

local function addApp()
    local added, errorMessage = exports["lb-phone"]:AddCustomApp({
        identifier = identifier, -- unique app identifier
        name = "JG Finance",
        description = "Manage your financed vehicles.",
        developer = "WL",
        defaultApp = false, --  set to true, the app will automatically be added to the player's phone
        size = 59812, -- the app size in kb
        ui = GetCurrentResourceName() .. "/ui/dist/index.html",
        icon = "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/icon.png",
        fixBlur = true -- set to true if you use em, rem etc instead of px in your css
    })

    if not added then
        print("Could not add app:", errorMessage)
    end
end

---@class NotificationData
---@field app? string Identifier of the app that sent the notification
---@field title string Title of the notification
---@field content? string Content of the notification
---@field thumbnail? string Thumbnail URL
---@field avatar? string Avatar URL
---@field showAvatar? boolean Whether to show an avatar placeholder
---@param data NotificationData
local function SendNotification(data)
    exports["lb-phone"]:SendNotification({
        app = identifier,
        title = data.title,
        content = data.content,
        thumbnail = data.thumbnail,
        avatar = data.avatar,
        showAvatar = data.showAvatar
    })
end

addApp()

AddEventHandler("onResourceStart", function(resource)
    if resource == "lb-phone" then
        addApp()
    end
end)

local vehicles = {}

RegisterNUICallback("Fetching", function(data,cb)
    if data.action == "fetching" then
        lib.callback("fetchfinancedvehicles", false, function(fetchedVehicles)
            vehicles = fetchedVehicles or {}
            cb(vehicles)
        end)
    else
        cb(false)
    end
end)

RegisterNUICallback("Payment", function(data, cb)
    if data.action ~= "payment" then
        return cb(false)
    end

    local index = data.index
    local amount = data.amount
    local type = data.type
    local uiData = data.data
    local vehicle = vehicles[index + 1]

    if not vehicle then
        return cb(false)
    end

    local vehicleData = json.decode(vehicle.finance_data)
    local vehiclepay = type == "payment" and vehicleData.recurring_payment or (vehicleData.total - vehicleData.paid)

    if uiData.vehicle and (vehicleData.vehicle ~= uiData.vehicle or amount ~= vehiclepay) then
        return cb(false)
    end

    lib.callback("MakePayment", false, function(success)
        if not success then
            SendNotification({
                title = "JG Finance",
                content = "Payment failed. Check your funds.",
            })
            return cb(false)
        end
        SendNotification({
            title = "JG Finance",
            content = type == "payment" and "Payment of $" .. amount .. " successful!" or "Vehicle fully paid off!",
        })
        lib.callback("fetchfinancedvehicles", false, function(test)
            vehicles = test or {}
            cb(vehicles)
        end)
    end, amount, type, vehicle)
end)