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

-- "WALEnabled" allows the UDataComponent to let doing Write-Ahead Logging
-- Where the data will be processed to written in WAL, before main data or backup
-- I recommend you to use this, unless you're having another reason to not
-- Luckily, I set this as naturally true in UDC
DataInfo.WALEnabled = true

-- "BackupEnabled" allows the UDataComponent to fallback into backup by searching latest data of version when data failed to gain
-- Naturally true in UDC
DataInfo.BackupEnabled = true

Players.PlayerAdded:Connect(function(player)
    -- This will access the record of a player from info
    -- using 'player' as Owner parameter is way to claim this record if there is no claimer
    -- and a defensive way to prevent another owner or player to write this record while currently belong to another player
    local Record = DataInfo:GetCurrentRecord(player.UserId, player)

    -- UDataComponent also allows you to add callbacks for debugging needs
    -- You can directly add the callbacks into GetPlayerData params
    -- Or use "record.Event" level function to add the data

    -- called when the data is modified, by Save() or Write(), although the data isn't commited yet
    Record.Event:OnWrite(function(Key)
        print("Data saved!")
    end)

    -- called when the data is finally commited to DataStore
    Record.Event:OnSaved(function(Key)
        print("Data loaded!")
    end)

    -- called when this record doing transaction with another record, for trading or giving
    local TemporaryCallback = Record.Event:OnTransacted(function(Key, TransactionInfo)
        print("This is in temporary connect")
    end)

    -- This will delete the callback directly after all of the function of callback called and ended
    -- For direct disconnecting, just use Disconnect()
    TemporaryCallback:DisconnectAfterCalled()

    -- Awake() is how you loaded and pulled data from DataStore
    -- simply, like you're waking up from sleep, that's how the data woken up from its "sleep"
    -- but, waking up doesn't mean you're ready overall
    local IsAwake = Record:Awake()
    if IsAwake then
        -- So, to make it ready...
        local IsReady = Record:Ready()
        -- Ready() is the crucial-step
        -- where your record is prepared, and your data is finally ready to be used
        -- but in condition, all of the conditions are true, the data is seemlessly ready

        -- make sure to check if Ready() is true, if false, it won't make the data of this record can be used
        if not IsReady then
            player:Kick("Unable to prepare data for this player...")
            return
        end

        local leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"

        local Money = Instance.new("IntValue")
        Money.Name = "Money"
        Money.Value = Record.Data and Record.Data.Money or 100 -- to prevent server crash, even though Record.Data.Money will always obtained, unless you're not checking them first
        Money.Parent = leaderstats

        local Level = Instance.new("IntValue")
        Level.Name = "Level"
        Level.Value = Record.Data and Record.Data.Level or 1
        Level.Parent = leaderstats
      
        local Rank = Instance.new("StringValue")
        Rank.Name = "Rank"
        Rank.Value = Record.Data and Record.Data.Rank or "Newbie"
        Rank.Parent = leaderstats

        -- I wouldn't recommend you to use ValueBase.Changed to write/edit the data
        -- Not only for my data-wrapper, but also for ProfileService/ProfileStore or DataStore2
        -- Naivety of using .Changed event would cause the lack of secure and lead you to race conditions
        -- Also, this will create a "Bomb" of requests to the datastore of Roblox

        -- So, I would recommend you to access the data before write
        -- This may be taking some time, but this is a better solution for your game scalability

        leaderstats.Parent = player

        -- those ValueBase instances are already handled by UDC too
        -- so you don't need to change the ValueBase everytime the record's data changed by manually
        -- because, when the specific data is changed along with a ValueBase bound with it...
        -- UDC will change the ValueBase's value with exact value of the data
        Record.Utilities:BindValue("Money", Money)
        Record.Utilities:BindValue("Level", Level)
        Record.Utilities:BindValue("Rank", Rank)

        -- Standby() helps you to prevent unsaved data when leaving or shutdown
        -- when you use this, UDC will release and save the data when you leave or shutdown
        -- so you shouldn't add another event or functions to release and save record manually
        -- Sleep() and WAL-Writing/ForceSave already inside
        local IsStandby = Record:Standby()
        if IsStandby then
            print("This record is currently standby!")
        end
    end
end)

-- want to call PlayerRemoving for release and saving record?
-- no, you don't need to. Standby() already handled it all, don't worry

Platform.Touched:Connect(function(Hit)
    local PlayerWhoHitted = Players:GetPlayerFromCharacter(Hit.Parent)
    if not PlayerWhoHitted then return end

    -- with putting PlayerWhoHitted or player into the loaded-already record, will be checked if this player was the owner of this record
    local PlayerData = DataInfo:GetPlayerData(PlayerWhoHitted.UserId, PlayerWhoHitted)

    -- "Write" is a function where you can write/edit specific(s) data of the player
    -- This is where you can mutate or modify the data of record
    local WrittenSuccessfully = PlayerData:Write(function(CurrentData)
        -- Adding 100 to Money in Data
        CurrentData.Money += 100

        -- Adding 1 level to Level in Data
        CurrentData.Level += 1
    end)

    if WrittenSuccessfully then
        print("This record wrote something in data successfully!")
    else
        print("Oops! The record unable to write the data")
    end
end)
