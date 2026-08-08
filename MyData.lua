local MyData = {}
MyData.__index = MyData

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

local __sc = script.ScopedMutex

local SDictionary = require(script.SDictionary)
local Mutex = require(__sc.Mutex)
local ScopedMutex = require(__sc)

local __GetTimestamp = {} -- { [Key: string] = timestamp: number }
local __SaveTimestamp = {} -- { [Key: string] = timestamp: number }
local __AutosaveTimestamp = {} -- { [Key: string] = timestamp: number }
local __SaveQueue = {} -- { [Key: string] = coroutine: thread }
local __DataCache = {} -- { [Key: string] = Data: any }
local __BoundRegistry = {} -- { [Key: string] = table }
local __LockSessions = ScopedMutex.new(Mutex)
local __LockTimers = {}
local __ExclusiveSafetyCalled = false

export type MyDataValidationDummy = {
	InsertPredicate: (self: MyDataValidationDummy, ThisData: any, Predicate: (ThisValue: any) -> any) -> any,
	RemovePredicate: (self: MyDataValidationDummy, ThisData: any) -> any,
}

export type MyDataRecord = {
	Get: (self: MyDataRecord, LoadRecovery: boolean?, ExclusivePlayer: Player?) -> any,
	Save: (self: MyDataRecord, Data: any, SegmentIndex: number?) -> (),
	Write: (self: MyDataRecord, WritingFunction: (CurrentData: any) -> any) -> (),
	Flush: (self: MyDataRecord) -> (),
	Recover: (self: MyDataRecord) -> boolean,
	Detach : (self: MyDataRecord) -> (),
	ForceSave: (self: MyDataRecord, Data: any, SegmentIndex: number?) -> (),
	ForceWrite: (self: MyDataRecord, WritingFunction: (CurrentData: any) -> any) -> (),
	SafeGet: (self: MyDataRecord, LoadRecovery: boolean?, ExclusivePlayer: Player?, LoadAttempts: number?, YieldTime: number?) -> any,
	SafeSave: (self: MyDataRecord, Data: any, SegmentIndex: number?) -> (),
	SafeWrite: (self: MyDataRecord, WritingFunction: (CurrentData: any) -> any) -> (),
	AcquireLockSession: (self: MyDataRecord, OwnerIdentity: string?, Timeout: number?) -> (boolean, number), 
	ReleaseLockSession: (self: MyDataRecord, OwnerIdentity: string) -> (),
	IsSessionLocked: (self: MyDataRecord, OwnerIdentity: string) -> boolean,
	BindExclusiveAccess: (self: MyDataRecord, ExclusivePlayer: Player) -> boolean,
	UnbindExclusiveAccess: (self: MyDataRecord) -> boolean,
	IsExclusiveAccessBound: (self: MyDataRecord) -> boolean,
	IsPlayerInExclusiveAccess: (self: MyDataRecord, PlayerThatAssumedExclusive: Player) -> boolean,
	CreateValidation: (self: MyDataRecord, ValidationFunction: (ValidationDummy: MyDataValidationDummy) -> any) -> (),
	SmartCleanCache: (self: MyDataRecord, Interval: number?) -> (),
	GetVersion: (self: MyDataRecord) -> number
}

export type MyDataCallbackFunctions = {
	OnDataLoading: (Key: string) -> (),
	OnDataLoaded: (Key: string, CurrentData: any) -> (),
	OnDataSaving: (Key: string) -> (),
	OnDataSaved: (Key: string, CurrentData: any) -> (),
	OnDataArchived: (Key: string, ArchivedData: any) -> (),
	OnDataRecovery: (Key: string) -> (),
	OnDataCached: (Key: string, CurrentData: any) -> (),
	OnDataRemoved: (Key: string, RemovedData: any) -> (),
	OnDataBinding: (Key: string, Data: any) -> (),
	OnDataUnbinding: (Key: string, Data: any) -> (),
	OnReleased: (Key: string) -> (),
	OnDataError: (Key: string, Reason: string) -> ()
}

export type MyDataInfo = {
	GetPlayerData: (self: MyDataInfo, Key: string | number, Callbacks: {MyDataCallbackFunctions?}) -> MyDataRecord,
	GetDataStoreName: (self: MyDataInfo) -> string | number,
	
	Enabled : boolean,
	RequestTimestampLimit : number,
	WALEnabled : boolean,
	WritingDataAgeEnabled : boolean,
	DefaultSaveAttempts : number,
	DefaultYieldAttempts : number,
	MaxKeyLength : number,
	BackupEnabled : boolean,
	StrictlyUnallowDetaching : boolean,
	BackupRemovedWhenDetached : boolean,
	AutoSaveEnabled : boolean,
	AutoSaveInterval : number,
	WALDataSuffix : string,
	WALMaxEntries : number,
	BackupDataSuffix : string,
	ExclusiveAccessEnabled : boolean,
	ExclusiveAccessAttempts : number,
	ExclusiveAccessExpiration : number,
	SwappingEnabled : boolean,
	CacheFlushingInterval : number,
	CanDataExpired : boolean,
	DataExpiredDuration : number,
	DataBlueprint : {any?},
	ErrorReasonNamespace : string,
	MessagingEnabled : boolean,
	MessagingNamespace : string,
	MessagingDebugEnabled : boolean,
	DefaultCacheCleanupInterval : number,
}

export type MyData = {
	InDataInfo: (DataStoreName: string, Scope: string?) -> MyDataInfo,
	SetDataInfoBlueprint: (DataInfo: MyDataInfo, PlayerDataBlueprint: {any?}) -> boolean
}

local function InPlayerData(meta, Key)
	assert(typeof(meta) == "table", "InPlayerData must be called from a MyDataInfo object")
	assert(typeof(Key) == "string" or typeof(Key) == "number", "Key must be a string or id")
	
	local record = {}
	record.key = Key
	
	local function dispatch(key, eventName, ...)
		local args = table.pack(...)

		local suc, err = pcall(function()
			local callbacks = meta._MyDataCallbacks:Get(eventName)
			
			if callbacks then
				local callback = callbacks[key]
				if not callback then return end
				
				callback(table.unpack(args))
			end
		end)
		
		if not suc then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData's callback error happened, reason: " .. tostring(err))
		end
	end
	
	local function deepclone(tab)
		if typeof(tab) ~= "table" then
			return tab
		end		
		local newTab = {}
		
		for k, v in pairs(tab) do
			newTab[k] = deepclone(v)
		end
		
		return newTab
	end
	
	local function get_blueprint()
		return deepclone(meta.DataBlueprint)
	end

	local function match_key(key : string, strid : string)
		key = tostring(key)
		strid = tostring(strid)
		
		if key == "" or strid == "" then
			return false
		end
		
		local startpos, endpos = string.find(key, strid, 1, true)
		if startpos == nil or endpos == nil then return false end
		
		local obtainedId = string.sub(key, startpos, endpos)
		if obtainedId == strid then
			return true
		end
		
		return false
	end
	
	local function ensure_exc_player(player)
		assert(typeof(player) == "Instance" and player:IsA("Player"))
		
		if not meta.ExclusiveAccessEnabled then
			return false
		end
		
		if RunService:IsClient() then
			warn("[" .. meta.ErrorReasonNamespace .. "]: Currently trying to set player as exclusive, named " .. player.Name ..  ", but called from clientt.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Currently trying to set player as exclusive, named " .. player.Name ..  ", but called from client.")
			return false
		end
		
		local id = player.UserId 		
		local strid = tostring(id)
		
		return match_key(record.key, strid)
	end
	
	local function call_backup(backup)
		local obtainedData = nil
		
		if not meta.BackupEnabled then
			return false, get_blueprint()
		end
		
		local _attempts = 0
		repeat
			local suc, err = pcall(function()
				obtainedData = backup:GetAsync(Key)
			end)
			
			if not suc then
				warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData's Get error happened, reason: " .. tostring(err))
				dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to obtain data from backup, trying to get data again...")
			end
			
			_attempts += 1
			task.wait(meta.BackupYieldDuration or 3)
		until _attempts >= meta.DefaultDataLoadingAttempts or obtainedData ~= nil
		
		if obtainedData == nil then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot check the record of the data from this key from backup")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to obtain data from backup, switching data to template/blueprint")
			
			return false, get_blueprint()
		end
		
		return true, obtainedData
	end
	
	local function write_data(data : DataStore, key, currentData)
		local dataSuccess, err = pcall(function()
			return data:UpdateAsync(key, function(old)
				return currentData				
			end)
		end)

		if not dataSuccess then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData unable to write Data, reason: " .. tostring(err))
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write Data.")

			return false, nil, "write_data_failed"
		end
		
		local clone = deepclone(currentData)
		dispatch(record.key, "OnDataSaved", clone)
		return true, dataSuccess, "write_data_success"
	end
	
	local function write_backup(backup : DataStore, key, currentData)
		if not meta.BackupEnabled then
			return false, nil, "backup_disabled"
		end
		
		local backupSuccess, err = pcall(function()
			return backup:UpdateAsync(key, function(old)
				return currentData				
			end)
		end)
		
		if not backupSuccess then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData unable to write Data to backup, reason: " .. tostring(err))
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write Data to backup.")
			
			return false, nil, "write_backup_failed"
		end
		
		return true, backupSuccess, "write_backup_success"
	end
	
	local function write_wal_optionally(wal : DataStore, data : DataStore, backup : DataStore, key, currentData)
		if not meta.WALEnabled then
			return false, nil, "wal_disabled"
		end
		
		local walSuccess, err = pcall(function()
			return wal:UpdateAsync(key, function(old)
				return currentData				
			end)
		end)

		if not walSuccess then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData unable to write WAL before actual Data, reason: " .. tostring(err))
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write WAL before actual Data.")

			return false, nil, "write_wal_failed"
		end
		
		local dataSuccess, _, _ = write_data(data, key, currentData)
		local backupSuccess, _, _ = write_backup(backup, key, currentData)
		
		if dataSuccess and backupSuccess then
			pcall(function()
				wal:RemoveAsync(key)
			end)
		else
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData unable to write Data or/and Backup, WAL remained for backup, reason: " .. tostring(err))
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write Data or/and Backup, WAL remained for backup soon.")
			
			return false, nil, "write_data_orand_backup_failed"
		end
		
		return true, walSuccess, "write_wal_success"
	end
	

	local function call_autosave(key, data : DataStore, wal : DataStore, backup : DataStore)
		local calledSince = workspace:GetServerTimeNow()
		
		while meta.Enabled and __DataCache[key] and __AutosaveTimestamp[key] do
			local now = workspace:GetServerTimeNow()
			local currentData = __DataCache[key]
			
			if now - calledSince >= meta.AutoSaveInterval then
				local status, _, codeStatus = write_wal_optionally(wal, data, backup, key, currentData)
				
				if codeStatus == "wal_disabled" then
					write_data(data, key, currentData)
					write_backup(backup, key, currentData)
				end
				
				calledSince = now
			end
			
			task.wait(1)
		end
	end
	
	local function create_lock_timer(ownerId, timeout)
		ownerId = tostring(ownerId)
		
		if not __LockTimers[ownerId] then
			__LockTimers[ownerId] = coroutine.create(function()
				local now = workspace:GetServerTimeNow()
				
				while meta.Enabled and __LockTimers[ownerId] do
					if now - __LockTimers[ownerId] >= timeout then
						record:ReleaseLockSession(ownerId)						
						break
					end
					
					task.wait(1)
				end
				
				__LockTimers[ownerId] = nil
			end)
			
			coroutine.resume(__LockTimers[ownerId])
		end
	end
	
	local function create_saving_record(key, wal : DataStore, data : DataStore, backup : DataStore)
		local calledSince = workspace:GetServerTimeNow()

		while meta.Enabled and __SaveQueue[key] and __DataCache[key] do
			local now = workspace:GetServerTimeNow()
			local currentData = __DataCache[key]
			
			if now - calledSince >= meta.DefaultSavingDataCountdown then
				local status, _, codeStatus = write_wal_optionally(wal, data, backup, key, currentData)
				
				if codeStatus == "wal_disabled" then
					write_data(data, key, currentData)
					write_backup(backup, key, currentData)
				end
				
				break
			end
			task.wait(1)
		end
		
		__SaveQueue[key] = nil
	end
	
	local function create_safe_saving_record(key, wal : DataStore, data : DataStore, backup : DataStore)
		local calledSince = workspace:GetServerTimeNow()
		
		while meta.Enabled and __SaveQueue[key] and __DataCache[key] do
			local now = workspace:GetServerTimeNow()
			local currentData = __DataCache[key]
			
			if now - calledSince >= meta.DefaultSavingDataCountdown then
				__LockSessions:Acquire(key)
				
				local status, _, codeStatus = write_wal_optionally(wal, data, backup, key, currentData)
				
				if codeStatus == "wal_disabled" then
					write_data(data, key, currentData)
					write_backup(backup, key, currentData)
				end
				
				__LockSessions:Release(key)
				
				break
			end
			task.wait(1)
		end
		
		__SaveQueue[key] = nil
	end
	
	local function is_data_valid(thisData, thisValue)
		if not meta.ValidationEnabled then return true end
		
		local trackedValidations = meta._TrackedValidations and meta._TrackedValidations[record.key]
		if not trackedValidations then return true end
		
		local predicate = trackedValidations[thisData]
		if not predicate then
			return true
		end
		
		return predicate(thisValue)
	end
	
	local function create_exclusive_safety(key)
		Players.PlayerRemoving:Connect(function(player)
			for key, bound in pairs(__BoundRegistry) do
				if bound.UserId == player.UserId then
					
				end
			end
		end)
		
		game:BindToClose(function()
			for key, bound in pairs(__BoundRegistry) do
				
			end
		end)
	end
	
	local function bind_exclusive_access(key, timeSinceBound, player : Player)
		if not meta.ExclusiveAccessEnabled then return end
		if not player then return end
		
		if __BoundRegistry[key] then
			return
		end
		
		__BoundRegistry[key] = {
			UserId = player.UserId,
			Since = timeSinceBound
		}
		
		if not __ExclusiveSafetyCalled then
			__ExclusiveSafetyCalled = true
			create_exclusive_safety(key)
		end
	end
	
	local function unbind_exclusive_access(key)
		
	end
	
	function record:Get(LoadRecovery : boolean?, ExclusivePlayer: Player?)
		dispatch(record.key, "OnDataLoading")

		local currentData = meta._CurrentDataStore
		local currentBackupData = meta._CurrentBackupDataStore
		local currentWALData = meta._CurrentWALDataStore

		local _attempts = 0
		local obtainedData = nil

		if __DataCache[record.key] then
			obtainedData = __DataCache[record.key]

			if ExclusivePlayer and obtainedData then
				if ensure_exc_player(ExclusivePlayer) then
					return true, obtainedData
				else
					return false, get_blueprint()
				end
			end
			
			local clone = deepclone(obtainedData)
			dispatch(record.key, "OnDataLoaded", clone)
			return true, obtainedData
		end
		
		local now = workspace:GetServerTimeNow()
		if __GetTimestamp[record.key] and now - __GetTimestamp[record.key] < meta.RequestTimestampCooldown then return false, nil end
		__GetTimestamp[record.key] = now
		
		if LoadRecovery then
			local recoverStatus, message = record:TryToRecover()
			if recoverStatus then
				dispatch(record.key, "OnDataRecovery")
			end
		end
		
		repeat
			local suc, err = pcall(function()
				obtainedData = currentData:GetAsync(Key)
			end)
			
			if not suc then
				warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData's Get error happened, reason: " .. tostring(err))
				dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: happened in Get's function, caused by failed to obtain data, trying to get data again...")		
			end
			
			_attempts += 1
			task.wait(meta.DefaultDataLoadingYieldDuration or 3)
		until _attempts >= meta.DefaultDataLoadingAttempts or obtainedData ~= nil
		
		if obtainedData == nil then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot obtain the record of the data from this key, trying to get data from backup")
			dispatch(record.key, "OnDataError", "Error happened while trying to obtain data, trying to obtain data from backup...")
			
			local status, backupData = call_backup(currentBackupData)
			
			if not __DataCache[record.key] then
				__DataCache[record.key] = if status then backupData else get_blueprint()
			end

			return status, backupData
		end
		
		if ExclusivePlayer and obtainedData then
			local status, data
			if ensure_exc_player(ExclusivePlayer) then
				status, data = true, obtainedData
			else
				status, data = false, get_blueprint()
			end
			
			if not __DataCache[record.key] then
				__DataCache[record.key] = data
			end
			
			return status, data
		end
		
		local clone = deepclone(obtainedData)
		dispatch(record.key, "OnDataLoaded", clone)
		
		if not __DataCache[record.key] then
			__DataCache[record.key] = obtainedData
		end		
		
		if not __AutosaveTimestamp[record.key] then
			__AutosaveTimestamp[record.key] = coroutine.create(call_autosave)
			
			coroutine.resume(__AutosaveTimestamp[record.key], record.key, currentData, currentWALData, currentBackupData)
		end
		
		return true, obtainedData
	end
	
	function record:Save(Data: any, SegmentIndex: number?)
		local now = workspace:GetServerTimeNow()
		if __SaveTimestamp[record.key] and now - __SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		__SaveTimestamp[record.key] = now
		
		dispatch(record.key, "OnDataSaving")
		
		if not __DataCache[record.key] then
			return false
		end
		
		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		
		local rejected = {}
		
		if SegmentIndex then
			if is_data_valid(SegmentIndex, Data) then
				__DataCache[record.key][SegmentIndex] = Data
			else
				table.insert(rejected, SegmentIndex)
			end
		else
			for thisData, thisValue in pairs(Data) do
				if is_data_valid(thisData, thisValue) then
					__DataCache[record.key][thisData] = thisValue
				else
					table.insert(rejected, thisData)
				end
			end
		end
		
		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		if not __SaveQueue[record.key] then
			__SaveQueue[record.key] = coroutine.create(create_saving_record)
			
			coroutine.resume(__SaveQueue[record.key], record.key, wal, data, backup)
						
			local clone = deepclone(__DataCache[record.key])
			dispatch(record.key, "OnDataCached", clone)
		end
		
		return true
	end
	
	function record:Write(WritingFunction: (CurrentData: any) -> any)
		local now = workspace:GetServerTimeNow()
		if __SaveTimestamp[record.key] and now - __SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		__SaveTimestamp[record.key] = now
		
		dispatch(record.key, "OnDataSaving")
		
		if not __DataCache[record.key] then
			return false
		end
				
		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		
		local before = __DataCache[record.key]
		local clone = deepclone(before)
		local resultFunction = WritingFunction(clone)
		
		if type(resultFunction) ~= "table" then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData's Write function must returns the/a table of param.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Write function isn't returning the table of param.")
			
			return false
		end
		
		local rejected = {}
		for thisData in pairs(before) do
			if resultFunction[thisData] == nil then
				__DataCache[record.key][thisData] = nil
			end
		end
		
		for thisData, thisValue in pairs(resultFunction) do
			if is_data_valid(thisData, thisValue) then
				__DataCache[record.key][thisData] = thisValue
			else
				table.insert(rejected, thisData)
			end
		end
		
		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
				
		if not __SaveQueue[record.key] then
			__SaveQueue[record.key] = coroutine.create(create_saving_record)
			
			coroutine.resume(__SaveQueue[record.key], record.key, wal, data, backup)
			dispatch(record.key, "OnDataCached", clone)
		end
				
		return true
	end
	
	function record:Flush()
		
	end
	
	function record:TryToRecover()
		if not meta.WALEnabled then
			return false, "wal_disabled"
		end
		
		local wal = meta._CurrentWALDataStore
		
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		
		local recoveredData = nil
		local _walAttempts = 0
		repeat
			local status, err = pcall(function()
				recoveredData = wal:GetAsync(record.key)
			end)
			
			if not status then
				warn("[" .. meta.ErrorReasonNamespace .. "]: Unexpected error happened when trying to recover data from WAL, with reason: " .. tostring(err))
				dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unexpected error happened, when trying to recover data that was dead from WAL.")
			end
			
			_walAttempts += 1
			task.wait(meta.DefaultDataLoadingYieldDuration or 3)
		until _walAttempts >= meta.DefaultDataLoadingAttempts or recoveredData ~= nil
		
		if not recoveredData then
			warn("[" .. meta.ErrorReasonNamespace .. "]: There is no WAL history to recover the data.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: There is no WAL history to recover the data, meaning the data has been successfully written or no record tracked.")
			
			return false, "failed_recover"
		end
		
		local status, _, message = write_wal_optionally(wal, data, backup, record.key, recoveredData)
		
		if not status then
			warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to recover data from WAL, with reason: " .. tostring(message))
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to recover data from WAL.")
			
			return false, "failed_recover"
		end
		
		return true, "success"
	end
	
	function record:Detach()
		if meta.StrictlyUnallowDetaching then
			return false, "unallowed_detach"
		end
		
		local currentData = __DataCache[record.key]
		if not currentData then
			return false, "not_cached"
		end
		local clone = deepclone(currentData)

		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		
		if meta.ArchivationEnabled then
			local archive = meta._CurrentArchivedDataStore
			pcall(function()
				archive:UpdateAsync(record.key .. "_" .. os.time(), function()
					return currentData
				end)
			end)
			
			dispatch(record.key, "OnDataArchived", clone)
		end
		
		pcall(function()
			data:RemoveAsync(record.key)
		end)
		
		if meta.BackupRemovedWhenDetached then
			pcall(function()
				backup:RemoveAsync(record.key)
			end)
		end
		
		__BoundRegistry[record.key] = nil
		__SaveTimestamp[record.key] = nil
		__GetTimestamp[record.key] = nil
		__SaveQueue[record.key] = nil
		__DataCache[record.key] = nil
		__AutosaveTimestamp[record.key] = nil
		
		dispatch(record.key, "OnDataRemoved", clone)
		return true, "success"
	end
	
	function record:ForceSave(Data: any, AlongCooldown : boolean?, SegmentIndex: number?)
		local now = workspace:GetServerTimeNow()
		if AlongCooldown and __SaveTimestamp[record.key] and now - __SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		__SaveTimestamp[record.key] = now
		
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		local wal = meta._CurrentWALDataStore
		
		dispatch(record.key, "OnDataSaving")		
		
		if not __DataCache[record.key] then
			return false
		end
		
		local rejected = {}

		if SegmentIndex then
			if is_data_valid(SegmentIndex, Data) then
				__DataCache[record.key][SegmentIndex] = Data
			else
				table.insert(rejected, SegmentIndex)
			end
		else
			for thisData, thisValue in pairs(Data) do
				if is_data_valid(thisData, thisValue) then
					__DataCache[record.key][thisData] = thisValue
				else
					table.insert(rejected, thisData)
				end
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		local clone = deepclone(__DataCache[record.key])
		local status, _, message = write_wal_optionally(wal, data, backup, record.key, __DataCache[record.key])
		
		if not status then
			if message == "wal_disabled" then
				write_data(data, record.key, __DataCache[record.key])
				write_backup(backup, record.key, __DataCache[record.key])

				return true
			end
			
			warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to save data, with reason: " .. tostring(message))
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to save data.")
			
			return false
		end
		
		dispatch(record.key, "OnDataSaved", clone)
		return true
	end
	
	function record:ForceWrite(Data: any, WritingFunction: (CurrentData: any) -> any, AlongCooldown : boolean?)
		local now = workspace:GetServerTimeNow()
		if AlongCooldown and __SaveTimestamp[record.key] and now - __SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		__SaveTimestamp[record.key] = now
		
		dispatch(record.key, "OnDataSaving")
		
		if not __DataCache[record.key] then
			return false
		end
		
		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore

		local before = __DataCache[record.key]
		local clone = deepclone(before)
		local resultFunction = WritingFunction(clone)

		if type(resultFunction) ~= "table" then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData's Write function must returns the/a table of param.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Write function isn't returning the table of param.")

			return false
		end

		local rejected = {}
		for thisData in pairs(before) do
			if resultFunction[thisData] == nil then
				__DataCache[record.key][thisData] = nil
			end
		end

		for thisData, thisValue in pairs(resultFunction) do
			if is_data_valid(thisData, thisValue) then
				__DataCache[record.key][thisData] = thisValue
			else
				table.insert(rejected, thisData)
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		local filteredData = __DataCache[record.key]
		local status, _, message = write_wal_optionally(wal, data, backup, record.key, filteredData)
		
		if not status then
			if message == "wal_disabled" then
				write_data(data, record.key, filteredData)
				write_backup(backup, record.key, filteredData)
				
				dispatch(record.key, "OnDataSaved", clone)

				return true
			end
			
			warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to save data, with reason: " .. tostring(message))
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to save data.")
			
			return false
		end
		
		dispatch(record.key, "OnDataSaved", clone)
		return true
	end
	
	function record:SafeGet(LoadRecovery: boolean?, ExclusivePlayer: Player?, LoadAttempts: number?, YieldTime: number?)
		dispatch(record.key, "OnDataLoading")

		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		local wal = meta._CurrentWALDataStore

		local attempts = LoadAttempts or meta.DefaultDataLoadingAttempts or 5
		local yieldTime = YieldTime or meta.DefaultDataLoadingYieldDuration or 3
		
		local status = false
		local obtainedData = nil
		
		if __DataCache[record.key] then
			obtainedData = __DataCache[record.key]
			local clone = deepclone(__DataCache[record.key])

			if ExclusivePlayer then
				if ensure_exc_player(ExclusivePlayer) then
					status = true
				else
					status, obtainedData = false, get_blueprint()
				end
			else
				status = true
			end

			dispatch(record.key, "OnDataLoaded", clone)
			return status, obtainedData
		end
		
		local now = workspace:GetServerTimeNow()
		if __GetTimestamp[record.key] and now - __GetTimestamp[record.key] < meta.RequestTimestampCooldown then return false, nil end
		__GetTimestamp[record.key] = now
				
		__LockSessions:Do(record.key, function()
			local _attempts = 0
			
			if LoadRecovery then
				local recoverStatus, message = record:TryToRecover()
				if recoverStatus then
					dispatch(record.key, "OnDataRecovery")
				end
			end
			
			repeat
				local success, result = pcall(function()
					obtainedData = data:GetAsync(record.key)
				end)
				
				if not success then
					warn("[" .. meta.ErrorReasonNamespace .. "]: Failed to load data, with reason: " .. tostring(result))
					dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed to load data.")
				end
				
				_attempts += 1
				task.wait(yieldTime)
			until _attempts >= attempts or obtainedData ~= nil
			
			if obtainedData == nil then
				warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot obtain the record of the data from this key, trying to get data from backup")
				dispatch(record.key, "OnDataError", "Error happened while trying to obtain data, trying to obtain data from backup...")

				local preStatus, backupData = call_backup(backup)

				if not __DataCache[record.key] then
					__DataCache[record.key] = if preStatus then backupData else get_blueprint()
				end

				status, obtainedData = preStatus, backupData
			else
				status = true
			end
			
			if ExclusivePlayer and obtainedData then
				if ensure_exc_player(ExclusivePlayer) then
					status = true
				else
					status, obtainedData = false, get_blueprint()
				end
			end
		end)
		
		if not __DataCache[record.key] then
			__DataCache[record.key] = obtainedData
		end		
		
		if not __AutosaveTimestamp[record.key] then
			__AutosaveTimestamp[record.key] = coroutine.create(call_autosave)

			coroutine.resume(__AutosaveTimestamp[record.key], record.key, data, wal, backup)
		end
		
		local clone = deepclone(obtainedData)
		dispatch(record.key, "OnDataLoaded", clone)
		
		return status, obtainedData
	end
	
	function record:SafeSave(Data: any, SegmentIndex: number?)
		local now = workspace:GetServerTimeNow()
		if __SaveTimestamp[record.key] and now - __SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		__SaveTimestamp[record.key] = now
		
		dispatch(record.key, "OnDataSaving")
		
		if not __DataCache[record.key] then
			return false
		end
		
		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		
		local rejected = {}

		if SegmentIndex then
			if is_data_valid(SegmentIndex, Data) then
				__DataCache[record.key][SegmentIndex] = Data
			else
				table.insert(rejected, SegmentIndex)
			end
		else
			for thisData, thisValue in pairs(Data) do
				if is_data_valid(thisData, thisValue) then
					__DataCache[record.key][thisData] = thisValue
				else
					table.insert(rejected, thisData)
				end
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		if not __SaveQueue[record.key] then
			__SaveQueue[record.key] = coroutine.create(create_safe_saving_record)
			
			coroutine.resume(__SaveQueue[record.key], record.key, wal, data, backup)
			
			local clone = deepclone(__DataCache[record.key])
			dispatch(record.key, "OnDataCached", clone)
		end
		
		return true
	end
	
	function record:SafeWrite(WritingFunction: (CurrentData: any) -> any)
		local now = workspace:GetServerTimeNow()
		if __SaveTimestamp[record.key] and now - __SaveTimestamp[record.key] < meta.RequestTimestampCooldown then return false end
		__SaveTimestamp[record.key] = now
		
		dispatch(record.key, "OnDataSaving")
		
		if not __DataCache[record.key] then
			return false
		end
		
		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		
		local before = __DataCache[record.key]
		local clone = deepclone(before)
		local resultFunction = WritingFunction(clone)

		if type(resultFunction) ~= "table" then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData's Write function must returns the/a table of param.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Write function isn't returning the table of param.")

			return false
		end

		local rejected = {}
		for thisData in pairs(before) do
			if resultFunction[thisData] == nil then
				__DataCache[record.key][thisData] = nil
			end
		end

		for thisData, thisValue in pairs(resultFunction) do
			if is_data_valid(thisData, thisValue) then
				__DataCache[record.key][thisData] = thisValue
			else
				table.insert(rejected, thisData)
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		if not __SaveQueue[record.key] then
			__SaveQueue[record.key] = coroutine.create(create_safe_saving_record)
			
			coroutine.resume(__SaveQueue[record.key], record.key, wal, data, backup)
			dispatch(record.key, "OnDataCached", __DataCache[record.key])
		end
		
		return true
	end
	
	function record:AcquireLockSession(OwnerIdentity: string?, Timeout: number?)
		local now = workspace:GetServerTimeNow()
		OwnerIdentity = OwnerIdentity or HttpService:GenerateGUID(false) .. "-" .. tostring(now)
		Timeout = Timeout or 10
		
		local isSuccess = __LockSessions:Acquire(OwnerIdentity)
		if not isSuccess then
			__LockSessions:Release(OwnerIdentity)
			return false, nil
		end
		
		create_lock_timer(OwnerIdentity, Timeout)
		return isSuccess, OwnerIdentity
	end
	
	function record:ReleaseLockSession(OwnerIdentity: string)
		local timer = __LockTimers[OwnerIdentity]
		if timer then
			coroutine.close(timer)
			__LockTimers[OwnerIdentity] = nil
		end
		
		__LockSessions:Release(OwnerIdentity)
		return true
	end
	
	function record:IsSessionLocked(OwnerIdentity: string)
		return __LockSessions:IsLocked(OwnerIdentity)
	end
	
	function record:BindExclusiveAccess(ExclusivePlayer: Player)
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end
		
		local id = ExclusivePlayer.UserId
		local data = deepclone(__DataCache[record.key])
		local now = workspace:GetServerTimeNow()
		
		if data.__bounds == nil then
			record:SafeWrite(function(CurrentData)
				CurrentData.__bounds = {}
				
				CurrentData.__bounds.id = id
				CurrentData.__bounds.since = now
				
				return CurrentData
			end)
			
			if __BoundRegistry[record.key] == nil then
				bind_exclusive_access(record.key, now, ExclusivePlayer)
			end			
			
			dispatch(record.key, "OnDataBinding", data)
			
			return true
		end
		
		dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Data is already bound to " .. data.__bounds.id .. "")
		return false
	end
	
	function record:UnbindExclusiveAccess()
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end
		
		local data = deepclone(__DataCache[record.key])
		
		if data.__bounds == nil or __BoundRegistry[record.key] == nil then 
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Data is not bound to any player.")
			return false
		end
		
		record:SafeWrite(function(CurrentData)
			CurrentData.__bounds = nil
			
			return CurrentData
		end)		
		
		unbind_exclusive_access(record.key)
		dispatch(record.key, "OnDataUnbinding", data)
		
		return true
	end
	
	function record:IsExclusiveAccessBound()
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end
		
		local data = deepclone(__DataCache[record.key])
		
		return data.__bounds ~= nil and __BoundRegistry[record.key] ~= nil
	end
	
	function record:IsPlayerInExclusiveAccess(PlayerThatAssumedExclusive: Player)
		if not meta.ExclusiveAccessEnabled then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. "Exclusive access is disabled.")
			return false
		end
		
		local data = deepclone(__DataCache[record.key])
		local id = PlayerThatAssumedExclusive.UserId
		
		return data.__bounds ~= nil and data.__bounds.id == id and __BoundRegistry[record.key] ~= nil and __BoundRegistry[record.key].UserId == id
	end
	
	function record:CreateValidation(ValidationFunction: (PredicateDummy: MyDataValidationDummy) -> any)
		local dummyMethods = {}
		local trackedValidations = meta._TrackedValidations[record.key] or {}
		meta._TrackedValidations[record.key] = trackedValidations
		
		local currentData = deepclone(__DataCache[record.key])
		
		function dummyMethods:InsertPredicate(ThisData : any, Predicate: (ThisValue: any) -> any)
			trackedValidations[ThisData] = Predicate
		end
		
		function dummyMethods:RemovePredicate(ThisData : any)
			trackedValidations[ThisData] = nil
		end
		
		ValidationFunction(dummyMethods)
	end
	
	function record:SmartCleanCache(Interval: number?)
		
	end
	
	function record:GetVersion()
		
	end
	
	return record
end

function MyData.InDataInfo(DataStoreName : string, Scope : string?, Configurations : {any?}) : MyDataInfo
	local _scope = Scope or "global"
	
	local self = setmetatable({}, MyData)
	
	self._DataPredicates = SDictionary.new("string", "table", {}) -- { [Key] = predicateFunction }
		
	self.Enabled = true
	self.ValidationEnabled = true
	self.RequestTimestampCooldown = 2
	self.DefaultSavingDataCountdown = 30
	self.DefaultDataLoadingAttempts = 5
	self.DefaultDataLoadingYieldDuration = 3
	self.WALEnabled = false
	self.WritingDataAgeEnabled = false
	self.DefaultSaveAttempts = 5
	self.DefaultYieldAttempts = 3
	self.MaxKeyLength = 50
	self.BackupEnabled = true
	self.BackupYieldDuration = 3
	self.StrictlyUnallowDetaching = true
	self.BackupRemovedWhenDetached = false
	self.AutoSaveEnabled = true
	self.AutoSaveInterval = 300
	self.WALDataSuffix = "_wal"
	self.WALMaxEntries = 50
	self.BackupDataSuffix = "_backup"
	self.ExclusiveAccessEnabled = true
	self.ExclusiveAccessAttempts = 5
	self.ExclusiveAccessExpiration = 24 -- 1 day = 24 hours
	self.SwappingEnabled = true
	self.CacheFlushingInterval = 5
	self.CanDataExpired = false
	self.DataExpiredDuration = 300
	self.DataBlueprint = {}
	self.ErrorReasonNamespace = "MyData"
	self.MessagingEnabled = false
	self.MessagingNamespace = "MyDataReplication"
	self.ArchivationEnabled = true
	self.ArchivationSuffix = "_archive"
	self.MessagingDebugEnabled = false
	self.DefaultCacheCleanupInterval = 300 -- 300 seconds
	
	self._CurrentDataStore = DataStoreService:GetDataStore(DataStoreName, _scope)
	self._CurrentWALDataStore = DataStoreService:GetDataStore(DataStoreName..self.WALDataSuffix, _scope)
	self._CurrentBackupDataStore = DataStoreService:GetDataStore(DataStoreName..self.BackupDataSuffix, _scope)
	self._CurrentArchivedDataStore = DataStoreService:GetDataStore(DataStoreName..self.ArchivationSuffix, _scope)
	self._DataStoreName = DataStoreName
	
	self._TrackedValidations = {} -- { [Key] = { Member = ValidationFunction, ... } }
	self._MyDataCallbacks = SDictionary.new("string", "table", {
		OnDataLoaded = {},
		OnDataSaved = {},
		OnDataCached = {},
		OnDataRemoved = {},
		OnDataBinding = {},
		OnDataUnbinding = {},
		OnReleased = {},
		OnDataError = {}
	})
	
	if Configurations then
		for key, value in pairs(Configurations) do
			self[key] = value
		end
	end
	
	return self
end

function MyData.SetDataInfoBlueprint(DataInfo : MyDataInfo, PlayerDataBlueprint : {any?}) : boolean
	self.DataBlueprint = PlayerDataBlueprint
	return true
end

function MyData:GetPlayerData(Key : string | number, Callbacks : {MyDataCallbackFunctions?}) : MyDataRecord
	if Callbacks then
		for key, value in pairs(Callbacks) do
			local currentFunc = self._MyDataCallbacks:Get(key)
			
			if currentFunc then
				currentFunc[Key] = value
			end
		end
	end
	
	return InPlayerData(self, Key) :: MyDataRecord
end

function MyData:GetDataStoreName() : string
	return self._DataStoreName
end

return MyData :: MyData
