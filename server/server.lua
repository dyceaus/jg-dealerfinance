lib.callback.register('fetchfinancedvehicles', function(source)
    local identifier = Framework.Server.GetPlayerIdentifier(source)
    return MySQL.query.await("SELECT finance_data, plate FROM " .. Framework.VehiclesTable .. " WHERE " .. Framework.PlayerIdentifier .. " = @identifier AND financed = 1", {
        ["@identifier"] = identifier
    })
end)

lib.callback.register('MakePayment', function(source, amount, paymenttype, vehicleData)
    local balance = Framework.Server.GetPlayerBalance(source, "bank")
    if amount > balance then
        print("Not enough money")
    end

    if paymenttype == "payment" then
        local newdata = vehicleData
        local finance_data = json.decode(newdata.finance_data)
        finance_data.paid = finance_data.paid + amount
        finance_data.seconds_to_next_payment = Config.FinancePaymentInterval * 60 * 60
        finance_data.seconds_to_repo = 0
        finance_data.payment_failed = false
        finance_data.payments_complete = finance_data.payments_complete + 1
        newdata.finance_data = json.encode(finance_data)
        if finance_data.payments_complete >= finance_data.total_payments then
            Framework.Server.PlayerRemoveMoney(source, amount, "bank")
            MySQL.Async.execute("UPDATE "..Framework.VehiclesTable.." SET finance_data = NULL, financed = 0 WHERE "..Framework.PlayerIdentifier.." = @identifier AND plate = @vehicle_id", {
                ["@identifier"] = Framework.Server.GetPlayerIdentifier(source),
                ["@vehicle_id"] = vehicleData.plate
            })
            return true
        end
        Framework.Server.PlayerRemoveMoney(source, amount, "bank")
        MySQL.Async.execute("UPDATE " .. Framework.VehiclesTable .. " SET finance_data = @finance_data WHERE " .. Framework.PlayerIdentifier .. " = @identifier AND plate = @vehicle_id", {
            ["@finance_data"] = newdata.finance_data,
            ["@identifier"] = Framework.Server.GetPlayerIdentifier(source),
            ["@vehicle_id"] = vehicleData.plate
        })
        return true
    else
        MySQL.Async.execute("UPDATE " .. Framework.VehiclesTable .. " SET finance_data = NULL, financed = 0 WHERE " .. Framework.PlayerIdentifier .. " = @identifier AND plate = @data", {
            ["@identifier"] = Framework.Server.GetPlayerIdentifier(source),
            ["@data"] = vehicleData.plate
        })

        Framework.Server.PlayerRemoveMoney(source, amount, "bank")
        return true
    end
end)