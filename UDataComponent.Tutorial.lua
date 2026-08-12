local UDataComponent = require(PATH.TO.UDataComponent)
local Players = game:GetService("Players")

-- As base example
local Platform = workspace.TestPlatform

-- This is the DataInfo level of UDataComponent, where all configurations belong
-- This will be "waking up" the constructor of data, where all data begin to processed continually
local DataInfo = UDataComponent.InDataInfo("MyGamePlayersData", "global")

-- Create ur configurations, unless you're using template configurations

-- "DataBlueprint" is where new player in your game get the template/blueprint of data
DataInfo.DataBlueprint = {
  Money = 100,
  Level = 1,
  Rank = "Newbie"
}

-- "AutoSaveEnabled" guarantees player to saving data every elapsed interval
DataInfo.AutoSaveEnabled = true

-- "AutoSaveInterval" sets the interval of auto-saving data of players, every player have a different timer.
-- Began since player joined the experience, this means 300 seconds of player joined the experience will auto-saved the data.
-- Then start back to count for next round
DataInfo.AutoSaveInterval = 300

-- "RequestTimestampCooldown" prevents the script to spamming request of write/read functions, such as Get(), Save(), Write(), etc.
DataInfo.RequestTimestampCooldown = 2

-- "WALEnabled" allows the UDataComponent to let doing Write-Ahead Logging
-- Where the data will be processed to written in WAL, before main data or backup
-- I recommend you to use this, unless you're having another reason to not
DataInfo.WALEnabled = true

-- "BackupEnabled" allows the UDataComponent to create a data backup to prevent data-loss
-- Backup will be written after main data
DataInfo.BackupEnabled = true

Players.PlayerAdded:Connect(function(player)
    -- This will access the PlayerData level of UDataComponent, where all data modifier can be accessed with
    local PlayerData = DataInfo:GetPlayerData(player.UserId)

    -- UDataComponent also allows you to add callbacks for debugging needs
    -- You can directly add the callbacks into GetPlayerData params
    -- Or use "OnConnect" level function to add the data

    PlayerData:OnConnect():OnDataSaved(function(Key, CloneData)
        print("Data saved!")
    end)

    PlayerData:OnConnect():OnDataLoaded(function(Key, CloneData)
        print("Data loaded!")
    end)

    local TemporaryCallback = PlayerData:OnConnect():OnDataCached(function(Key, CloneData)
        print("This is in temporary connect")
    end)

    -- This will delete the callback directly after all of the function of callback called and ended
    -- For direct disconnecting, just use Disconnect()
    TemporaryCallback:DisconnectAfterCalled()

    -- 'true' in here is checking if there is losing data of player that haven't been saved yet
    -- So when there is a log of pending-ed data, it will automatically write previous data
    -- But, this is just only required when "WALEnabled" is true or WAL is enabled
    local isSuccess, data = PlayerData:Get(true)

    -- This does mean the data is successfully obtained, careless for blueprint data or actual data
    if isSuccess then
        local leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"

        local Money = Instance.new("IntValue")
        Money.Name = "Money"
        Money.Value = data.Money
        Money.Parent = leaderstats

        local Level = Instance.new("IntValue")
        Level.Name = "Level"
        Level.Value = data.Level
        Level.Parent = leaderstats
      
        local Rank = Instance.new("StringValue")
        Rank.Name = "Rank"
        Rank.Value = data.Rank
        Rank.Parent = leaderstats

        -- I wouldn't recommend you to use ValueBase.Changed to write/edit the data
        -- Not only for my data-wrapper, but also for ProfileService/DataStore2
        -- Naivety of using .Changed event would cause the lack of secure and lead you to race conditions
        -- Also, this will create a "Bomb" of requests to the datastore of Roblox

        -- So, I would recommend you to access the data before write
        -- This may be taking some time, but this is a better solution for your game scalability

        leaderstats.Parent = player
    end

    -- This allow UDataComponent in PlayerData's level to clean the useless cache every 30 seconds in interval
    -- To gain a better performance in server
    PlayerData:SmartCleanCache(300) 
end)

Players.PlayerRemoving:Connect(function(player)
    local PlayerData = DataInfo:GetPlayerData(player.UserId)

    -- This will save the data before cache is cleaned
    PlayerData:Flush()
end)

Platform.Touched:Connect(function(Hit)
    local PlayerWhoHitted = Players:GetPlayerFromCharacter(Hit.Parent)
    if not PlayerWhoHitted then return end

    local PlayerData = DataInfo:GetPlayerData(PlayerWhoHitted.UserId)

    -- "Write" is a function where you can write/edit specific(s) data of the player
    -- Without mind other data to rewrite them back
    PlayerData:Write(function(CurrentData)
        -- Adding 100 to Money in Data
        CurrentData.Money += 100

        -- Adding 1 level to Level in Data
        CurrentData.Level += 1
        return CurrentData -- Don't forget to return the parameter! Because that is the modified data that you did
    end)
end)
