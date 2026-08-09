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
local __SavePendingQueue = {} -- { [Key: string] = {Key, Data, WAL, Backup, IsSafe } }
local __DataCache = {} -- { [Key: string] = Data: any }
local __BoundRegistry = {} -- { [Key: string] = table }
local __LockSessions = ScopedMutex.new(Mutex)
local __LockTimers = {}

local __ExclusiveTimerCalled = false
local __AutosaveDied = false
local __ExclusiveSafetyCalled = false
local __IsRunning = false

export type MyDataValidationDummy = {
	-- Inserting a predication of data whereas the data can be written when the predicate fulfilled
	InsertPredicate: (self: MyDataValidationDummy, ThisData: any, Predicate: (ThisValue: any) -> any) -> any,
	RemovePredicate: (self: MyDataValidationDummy, ThisData: any) -> any,
	
	InsertClamp: (self: MyDataValidationDummy, ThisData: any, Min: number, Max: number) -> any,
	RemoveClamp: (self: MyDataValidationDummy, ThisData: any) -> any,
	
	InsertSchema: (self: MyDataValidationDummy, ThisData: any, Type: string) -> any,
	RemoveSchema: (self: MyDataValidationDummy, ThisData: any) -> any
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
	
	local function is_still_exclusive(key, strid)
		assert(typeof(strid) == "string")
		
		local days = meta.ExclusiveAccessExpiration
		local now = workspace:GetServerTimeNow()
		local dayInSec = 60 * 60 * 24
		
		local timeout = dayInSec * days
		
		local id = tonumber(strid)
		if id == nil then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to get the ID of player while trying to check the exlusive binding.")
			return false
		end
				
		local bound = __BoundRegistry[key]
		if not bound then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Failed because the data wasn't bound with this player.")
			return false
		end
				
		local boundId, since = bound.UserId, bound.Since
		if not id or not since then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to get ID or time since bound from this player.")
			return false
		end
						
		return id == boundId and now - since < timeout
	end

	local function match_key(oriKey, strid : string)
		local key = tostring(oriKey)
		strid = tostring(strid)
		
		if key == "" or strid == "" then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Empty key or id is not allowed.")
			return false
		end
		
		local startpos, endpos = string.find(strid, key, 1, true)
		if startpos == nil or endpos == nil then 
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Unable to match key with id.")
			return false 
		end
		
		local obtainedId = string.sub(key, startpos, endpos)
		if obtainedId == strid and is_still_exclusive(oriKey, strid) then
			return true
		end
		
		dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: The data of this key isn't bound with this player.")
		return false
	end
	
	local function ensure_exc_player(key, player)
		assert(typeof(player) == "Instance" and player:IsA("Player"))
		
		if not meta.ExclusiveAccessEnabled then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Exclusive access is disabled.")
			return false
		end
		
		if RunService:IsClient() then
			warn("[" .. meta.ErrorReasonNamespace .. "]: Currently trying to set player as exclusive, named " .. player.Name ..  ", but called from clientt.")
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Currently trying to set player as exclusive, named " .. player.Name ..  ", but called from client.")
			return false
		end
		
		local strid = tostring(player.UserId)
		
		return match_key(key, strid)
	end
	
	local function call_backup(backup)
		local obtainedData = nil
		
		if not meta.BackupEnabled then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Backup is disabled.")
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
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write Data.")
			
			return false, nil, "write_data_failed"
		end
				
		local clone = deepclone(currentData)
		dispatch(key, "OnDataSaved", clone)
				
		return true, dataSuccess, "write_data_success"
	end
	
	local function write_backup(backup : DataStore, key, currentData)
		if not meta.BackupEnabled then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Backup is disabled.")
			return false, nil, "backup_disabled"
		end
		
		local backupSuccess, err = pcall(function()
			return backup:UpdateAsync(key, function(old)
				return currentData				
			end)
		end)
		
		if not backupSuccess then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData unable to write Data to backup, reason: " .. tostring(err))
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write Data to backup.")
			
			return false, nil, "write_backup_failed"
		end
		
		return true, backupSuccess, "write_backup_success"
	end
	
	local function write_wal_optionally(wal : DataStore, data : DataStore, backup : DataStore, key, currentData)
		if not meta.WALEnabled then
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: WAL is disabled.")
			return false, nil, "wal_disabled"
		end
		
		local walSuccess, err = pcall(function()
			wal:UpdateAsync(key, function(old)
				return currentData				
			end)
		end)

		if not walSuccess then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData unable to write WAL before actual Data, reason: " .. tostring(err))
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write WAL before actual Data.")

			return false, nil, "write_wal_failed"
		end
		
		local dataSuccess, _, _ = write_data(data, key, currentData)
		local backupSuccess, _, _ = write_backup(backup, key, currentData)
		
		if dataSuccess and backupSuccess and walSuccess then
			pcall(function()
				wal:RemoveAsync(key)
			end)
		else
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData unable to write Data or/and Backup, WAL remained for backup, reason: " .. tostring(err))
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Error happened while trying to write Data or/and Backup, WAL remained for backup soon.")
			
			return false, nil, "write_data_orand_backup_failed"
		end
		
		return true, walSuccess, "write_wal_success"
	end
	
	local function call_flush(key, data : DataStore, wal : DataStore, backup : DataStore)
		local currentData = __DataCache[key]
		if not currentData then 
			dispatch(key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Data is not loaded and cannot able to find the data record from cache.")
			return false 
		end
		
		local status, _, codeStatus = write_wal_optionally(wal, data, backup, key, currentData)
		if codeStatus == "wal_disabled" then
			write_data(data, key, currentData)
			write_backup(backup, key, currentData)
		end
		
		for i, pending in ipairs(__SavePendingQueue) do
			if pending.Key == key then
				table.remove(__SavePendingQueue, i)
				break
			end
		end
				
		return true
	end

	local function call_autosave(key, data : DataStore, wal : DataStore, backup : DataStore)
		local calledSince = workspace:GetServerTimeNow()
		
		while meta.Enabled and __DataCache[key] and __AutosaveTimestamp[key] and not __AutosaveDied do
			local now = workspace:GetServerTimeNow()
			local currentData = __DataCache[key]
			
			if now - calledSince >= meta.AutoSaveInterval then
				local status, _, codeStatus = write_wal_optionally(wal, data, backup, key, currentData)
				
				if codeStatus == "wal_disabled" then
					local _, _, _ = write_data(data, key, currentData)
					local _, _, _ = write_backup(backup, key, currentData)
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
	
	local function run_save_queue()
		if __IsRunning then return end
		__IsRunning = true
		
		task.spawn(function()
			while meta.Enabled do
				local count = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
				local processed = 0
				local max = meta.MaxDataSavingPerTick
				
				while #__SavePendingQueue > 0 and processed < max and count > 0 do
					local obj = table.remove(__SavePendingQueue, 1) -- First in first out
					
					local currentData = __DataCache[obj.Key]
					if currentData then
						local function commit()
							local status, _, message = write_wal_optionally(obj.WAL, obj.Data, obj.Backup, obj.Key, currentData)

							if message == "wal_disabled" then
								local _, _, _ = write_data(obj.Data, obj.Key, currentData)
								local _, _, _ = write_backup(obj.Backup, obj.Key, currentData)
							end
						end
						
						if obj.IsSafe then
							__LockSessions:Do(obj.Key, commit)
						else
							commit()
						end
					end
					
					processed += 1
					count -= 1
				end
				
				task.wait(1)
			end
		end)
	end
	
	local function enqueue_save(key, data, wal, backup, isSafe)
		for _, pending in ipairs(__SavePendingQueue) do
			if pending.Key == key then
				return false
			end
		end
		
		table.insert(__SavePendingQueue, {
			Key = key,
			Data = data,
			WAL = wal,
			Backup = backup,
			IsSafe = isSafe
		})
		
		run_save_queue()
		return true
	end
	
	local function is_data_valid(thisData, thisValue)
		if not meta.ValidationEnabled then 
			return true 
		end
		
		local trackedValidations = meta._TrackedValidations and meta._TrackedValidations[record.key]
		if not trackedValidations then return true end
		
		local predicate = trackedValidations[thisData]
		if not predicate then
			return true
		end
		
		return predicate(thisValue)
	end
	
	local function is_schema_valid(thisData, thisValue)
		if not meta.ValidationEnabled then return true end
		
		local trackedSchemas = meta._TrackedSchemas and meta._TrackedSchemas[record.key]
		if not trackedSchemas then return true end
		
		local schema = trackedSchemas[thisData]
		if not schema then return true end
		
		return typeof(thisValue) == schema
	end
	
	local function clamp_value(thisData, thisValue)
		if not meta.ValidationEnabled then return thisValue end
		
		local trackedClamps = meta._TrackedClamps and meta._TrackedClamps[record.key]
		if not trackedClamps then return thisValue end
		
		local clampMin = trackedClamps[thisData] and trackedClamps[thisData].Min
		local clampMax = trackedClamps[thisData] and trackedClamps[thisData].Max
		if not clampMin or not clampMax then return thisValue end
		
		return math.clamp(thisValue, clampMin, clampMax)
	end
	
	local function check_validation(key, thisData, thisValue)
		if is_schema_valid(thisData, thisValue) then
			if is_data_valid(thisData, thisValue) then
				__DataCache[key][thisData] = clamp_value(thisData, thisValue)
				return true
			else
				return false
			end
		end
		
		return false
	end
	
	local function create_exclusive_safety(key)
		Players.PlayerRemoving:Connect(function(player)
			if __AutosaveDied then return end
			
			for key, bound in pairs(__BoundRegistry) do
				if bound.UserId == player.UserId then
					call_flush(key, meta._CurrentDataStore, meta._CurrentWALDataStore, meta._CurrentBackupDataStore)
					__BoundRegistry[key] = nil
				end
			end
			
			for key, data in pairs(__DataCache) do
				if typeof(data) == "table" and data.__bounds and data.__bounds.id == player.UserId then
					__DataCache[key] = nil
					__SavePendingQueue[key] = nil
					__GetTimestamp[key] = nil
					__SaveTimestamp[key] = nil
					__AutosaveTimestamp[key] = nil
				end
			end
		end)
		
		game:BindToClose(function()
			__AutosaveDied = true
			
			local pendingTask = 0
			for key, bound in pairs(__BoundRegistry) do
				pendingTask += 1
				task.spawn(bound.Coroutine, pendingTask)
			end
			
			local remainingTime = 0
			while pendingTask > 0 and remainingTime < 25 do
				task.wait(1)
				remainingTime += 1
			end
		end)
	end
	
	local function bind_exclusive_access(key, timeSinceBound, player : Player)
		if not meta.ExclusiveAccessEnabled then 
			return 
		end
		if not player then return end
		
		if __BoundRegistry[key] then
			return
		end
		
		__BoundRegistry[key] = {
			UserId = player.UserId,
			Since = timeSinceBound,
			Coroutine = function(pendingTask)
				call_flush(key, meta._CurrentDataStore, meta._CurrentWALDataStore, meta._CurrentBackupDataStore)
				pendingTask -= 1
			end
		}
		
		if not __ExclusiveSafetyCalled then
			__ExclusiveSafetyCalled = true
			create_exclusive_safety(key)
		end
		
		dispatch(key, "OnDataBinding", __DataCache[key])
	end
	
	local function unbind_exclusive_access(key)
		if not meta.ExclusiveAccessEnabled then return end
		if not __BoundRegistry[key] then return end
		
		__BoundRegistry[key] = nil
		dispatch(key, "OnDataUnbinding", __DataCache[key])
	end
	
	local function run_exclusive_timer(data, wal, backup)
		if __ExclusiveTimerCalled then return end
		__ExclusiveTimerCalled = true

		task.spawn(function()
			while meta.Enabled and meta.ExclusiveAccessEnabled do
				local now = workspace:GetServerTimeNow()

				for key, bound in pairs(__BoundRegistry) do
					local since = bound.Since

					local dayInSec = 24 * 60 * 60
					local timeout = dayInSec * meta.ExclusiveAccessExpiration

					if now - since > timeout then
						__DataCache[key].__bounds = nil
						call_flush(key, data, wal, backup)
						
						unbind_exclusive_access(key)
					end
				end
			end
		end)
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
				if ensure_exc_player(record.key, ExclusivePlayer) then
					return true, obtainedData
				else
					dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() returns blueprint/template of data, because the data is bound to another player.")
					return false, get_blueprint()
				end
			end
			
			local clone = deepclone(obtainedData)
			dispatch(record.key, "OnDataLoaded", clone)
			return true, obtainedData
		end
		
		local now = workspace:GetServerTimeNow()
		if __GetTimestamp[record.key] and now - __GetTimestamp[record.key] < meta.RequestTimestampCooldown then 
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() halted, waiting for cooldown.")
			return false, nil 
		end
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
			local dataResult = if status then backupData else get_blueprint()
			
			if dataResult.__bounds then
				local id = dataResult.__bounds.id
				local since = dataResult.__bounds.since
				
				local dayInSec = 60 * 60 * 24
				local days = meta.ExclusiveAccessExpiration or 1

				local timeout = dayInSec * days

				if workspace:GetServerTimeNow() - since < timeout then
					local plr = Players:GetPlayerByUserId(id)
					bind_exclusive_access(record.key, since, plr)
				end
			end
			
			if not __DataCache[record.key] then
				__DataCache[record.key] = dataResult
			end
			local _, _, _ = write_data(currentData, record.key, dataResult) -- this will rewrite the main datastore when backup un/obtained the data

			return status, backupData
		else
			if obtainedData.__bounds then
				local id = obtainedData.__bounds.id
				local since = obtainedData.__bounds.since
				
				local dayInSec = 60 * 60 * 24
				local days = meta.ExclusiveAccessExpiration or 1
				
				local timeout = dayInSec * days
				
				if workspace:GetServerTimeNow() - since < timeout then
					local plr = Players:GetPlayerByUserId(id)
					bind_exclusive_access(record.key, since, plr)
				end
			end
		end
		
		if ExclusivePlayer and obtainedData then
			if not __DataCache[record.key] then
				__DataCache[record.key] = obtainedData
			end
			
			local status, data
			if ensure_exc_player(record.key, ExclusivePlayer) then
				return true, obtainedData
			else
				dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Get() returns blueprint/template of data, because the data is bound to another player.")
				return false, get_blueprint()
			end
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
		if __SaveTimestamp[record.key] and now - __SaveTimestamp[record.key] < meta.RequestTimestampCooldown then 
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Save() halted, waiting for cooldown.")
			return false 
		end
		__SaveTimestamp[record.key] = now
		
		dispatch(record.key, "OnDataSaving")
		
		if not __DataCache[record.key] then
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save data, because data is not loaded yet.")
			return false
		end
		
		local wal = meta._CurrentWALDataStore
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		
		local rejected = {}
		
		if SegmentIndex then
			local success = check_validation(record.key, SegmentIndex, Data)
			if not success then
				table.insert(rejected, Data)
			end
		else
			for thisData, thisValue in pairs(Data) do
				local success = check_validation(record.key, thisData, thisValue)
				if not success then
					table.insert(rejected, thisValue)
				end
			end
		end
		
		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		enqueue_save(record.key, data, wal, backup, false)
		
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
			local success = check_validation(record.key, thisData, thisValue)
			
			if not success then
				table.insert(rejected, thisValue)
			end
		end
		
		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
				
		enqueue_save(record.key, data, wal, backup, false)
				
		return true
	end
	
	function record:Flush()
		local data = meta._CurrentDataStore
		local backup = meta._CurrentBackupDataStore
		local wal = meta._CurrentWALDataStore
		
		return call_flush(record.key, data, wal, backup)
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
				archive:UpdateAsync(record.key .. "_" .. workspace:GetServerTimeNow(), function()
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
		__DataCache[record.key] = nil
		__AutosaveTimestamp[record.key] = nil
		
		for i, pending in ipairs(__SavePendingQueue) do
			if pending.Key == record.key then
				table.remove(__SavePendingQueue, i)
				break
			end
		end
		
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
			local success = check_validation(record.key, SegmentIndex, Data)
			
			if not success then
				table.insert(rejected, Data)
			end
		else
			for thisData, thisValue in pairs(Data) do
				local success = check_validation(record.key, thisData, thisValue)
				
				if not success then
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
			local success = check_validation(record.key, thisData, thisValue)
			
			if not success then
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
				if ensure_exc_player(record.key, ExclusivePlayer) then
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
				local dataResult = if preStatus then backupData else get_blueprint()
				
				if dataResult.__bounds then
					local id = dataResult.__bounds.id
					local since = dataResult.__bounds.since
					
					local dayInSec = 60 * 60 * 24
					local days = meta.ExclusiveAccessExpiration or 1

					local timeout = dayInSec * days

					if workspace:GetServerTimeNow() - since < timeout then
						local plr = Players:GetPlayerByUserId(id)
						bind_exclusive_access(record.key, since, plr)
					end
				end

				if not __DataCache[record.key] then
					__DataCache[record.key] = dataResult
				end
				local _, _, _ = write_data(data, record.key, dataResult) -- this will rewrite the main datastore when backup un/obtained the data

				status, obtainedData = preStatus, backupData
			else
				if obtainedData.__bounds then
					local id = obtainedData.__bounds.id
					local since = obtainedData.__bounds.since
					
					local dayInSec = 60 * 60 * 24
					local days = meta.ExclusiveAccessExpiration or 1

					local timeout = dayInSec * days

					if workspace:GetServerTimeNow() - since < timeout then
						local plr = Players:GetPlayerByUserId(id)
						bind_exclusive_access(record.key, since, plr)
					end
				end
				
				status = true
			end
			
			if ExclusivePlayer and obtainedData then
				if ensure_exc_player(record.key, ExclusivePlayer) then
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
			local success = check_validation(record.key, SegmentIndex, Data)
			
			if not success then
				table.insert(rejected, Data)
			end
		else
			for thisData, thisValue in pairs(Data) do
				local success = check_validation(record.key, thisData, thisValue)
				
				if not success then
					table.insert(rejected, thisValue)
				end
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		enqueue_save(record.key, data, wal, backup, true)
		
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
			local success = check_validation(record.key, thisData, thisValue)
			
			if not success then
				table.insert(rejected, thisValue)
			end
		end

		if #rejected > 0 then
			warn("[" .. meta.ErrorReasonNamespace .. "]: " .. " MyData cannot save some of datas, because those are not valid.")
			dispatch(record.key, "OnDataError", "[" .. meta.ErrorReasonNamespace .. "]: Some of datas are invalid, some of rejected datas are: " .. table.concat(rejected, ", ") .. ".")
		end
		
		enqueue_save(record.key, data, wal, backup, true)
		
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
		local trackedSchemas = meta._TrackedSchemas[record.key] or {}
		local trackedClamps = meta._TrackedClamps[record.key] or {}
		
		meta._TrackedValidations[record.key] = trackedValidations
		meta._TrackedSchemas[record.key] = trackedSchemas
		meta._TrackedClamps[record.key] = trackedClamps
		
		local currentData = deepclone(__DataCache[record.key])
		
		-- Inserting a predication of data whereas the data can be written when the predicate fulfilled
		function dummyMethods:InsertPredicate(ThisData : any, Predicate: (ThisValue: any) -> any)
			trackedValidations[ThisData] = Predicate
		end
		
		function dummyMethods:RemovePredicate(ThisData : any)
			trackedValidations[ThisData] = nil
		end
		
		function dummyMethods:InsertSchema(ThisData : any, Type: string)
			trackedSchemas[ThisData] = Type
		end
		
		function dummyMethods:RemoveSchema(ThisData : any)
			trackedSchemas[ThisData] = nil
		end
		
		function dummyMethods:InsertClamp(ThisData : any, Min: number, Max: number)
			trackedClamps[ThisData] = {Min = Min, Max = Max}
		end
		
		function dummyMethods:RemoveClamp(ThisData : any)
			trackedClamps[ThisData] = nil
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
	self.ExclusiveAccessExpiration = 1 -- 1 Day
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
	self.MaxDataSavingPerTick = 4
	
	self._CurrentDataStore = DataStoreService:GetDataStore(DataStoreName, _scope)
	self._CurrentWALDataStore = DataStoreService:GetDataStore(DataStoreName..self.WALDataSuffix, _scope)
	self._CurrentBackupDataStore = DataStoreService:GetDataStore(DataStoreName..self.BackupDataSuffix, _scope)
	self._CurrentArchivedDataStore = DataStoreService:GetDataStore(DataStoreName..self.ArchivationSuffix, _scope)
	self._DataStoreName = DataStoreName
	
	self._TrackedValidations = {} -- { [Key] = { Member = ValidationFunction, ... } }
	self._TrackedSchemas = {} -- { [Key] = { Member = ValidationFunction, ... } }
	self._TrackedClamps = {} -- { [Key] = { Member = ValidationFunction, ... } }
	
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
