local MyData = {}
MyData.__index = MyData

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")

local SDictionary = require(script.SDictionary)
local Mutex = require(script.Mutex)

local __SaveQueue = {} -- { [Key: string] = boolean: boolean }
local __BoundRegistry = {} -- { [Key: string] = PlayerId: number }
local __LockSessions = Mutex.new()
local __ShutdownCalled = false

export type MyDataValidationDummy = {
	InsertPredicate: (self: MyDataValidationDummy, Predicate: boolean) -> (),
	RemovePredicate: (self: MyDataValidationDummy, PredicateIndex: number) -> (),
}

export type MyDataRecord = {
	Get: (self: MyDataRecord, ExclusivePlayer: Player?) -> any,
	Set: (self: MyDataRecord, Data: any, SegmentIndex: number?) -> (),
	Write: (self: MyDataRecord, WritingFunction: (CurrentData: any) -> any) -> (),
	Flush: (self: MyDataRecord) -> (),
	Recover: (self: MyDataRecord) -> boolean,
	Detach : (self: MyDataRecord) -> (),
	ForceSet: (self: MyDataRecord, Data: any, SegmentIndex: number?) -> (),
	SafeGet: (self: MyDataRecord, ExclusivePlayer: Player?, LoadAttempts: number?, YieldTime: number?) -> any,
	SafeSet: (self: MyDataRecord, Data: any, SegmentIndex: number?, SetAttempts: number?, YieldTime: number?) -> (),
	SafeWrite: (self: MyDataRecord, WritingFunction: (CurrentData: any) -> any, LoadAttempts: number?, SetAttempts: number?, YieldTime: number?) -> (),
	AcquireLockSession: (self: MyDataRecord, OwnerIdentity: string?, Timeout: number?) -> (boolean, number), 
	ReleaseLockSession: (self: MyDataRecord, OwnerIdentity: string) -> (),
	IsSessionLocked: (self: MyDataRecord, OwnerIdentity: string) -> boolean,
	BindExclusiveAccess: (self: MyDataRecord, ExclusivePlayer: Player) -> boolean,
	UnbindExclusiveAccess: (self: MyDataRecord) -> boolean,
	IsExclusiveAccessBound: (self: MyDataRecord, ExclusivePlayer: Player) -> boolean,
	IsPlayerInExclusiveAccess: (self: MyDataRecord, PlayerThatAssumedExclusive: Player) -> boolean,
	CreateValidation: (self: MyDataRecord, ValidationFunction: (ValidationDummy: MyDataValidationDummy) -> any) -> (),
	SmartCleanCache: (self: MyDataRecord, Interval: number?) -> ()
}

export type MyDataCallbackFunctions = {
	OnDataLoaded: (Key: string, CurrentData: {any?}) -> (),
	OnDataSaved: (Key: string, PreviousData: {any?}, CurrentData: {any?}) -> (),
	OnDataRemoved: (Key: string, RemovedData: {any?}) -> (),
	OnDataBinding: (Key: string, Data: {any?}) -> (),
	OnDataUnbinding: (Key: string, Data: {any?}) -> (),
	OnReleased: (Key: string) -> (),
	OnDataError: (Key: string, Reason: string) -> ()
}

export type MyDataInfo = {
	GetPlayerData: (self: MyDataInfo, Key: string, Callbacks: {MyDataCallbackFunctions?}) -> MyDataRecord,
	GetDataStoreName: (self: MyDataInfo) -> string,
	RemovePlayerData: (self: MyDataInfo, Key: string) -> boolean,
	
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

local function InPlayerData(self_param, Key)
	assert(typeof(self_param) == "table", "InPlayerData must be called from a MyDataInfo object")
	assert(typeof(Key) == "string", "Key must be a string or id")
	
	local meta = getmetatable(self_param)
	
	local record = {}
	
	function record:Get(ExclusivePlayer: Player?)
		
	end
	
	function record:Set(Data: any, SegmentIndex: number?)
		
	end
	
	function record:Write(Data: any, WritingFunction: (CurrentData: any) -> any)
		
	end
	
	function record:Flush()
		
	end
	
	function record:Recover()
		
	end
	
	function record:Detach()
		
	end
	
	function record:ForceSet(Data: any, SegmentIndex: number?)
		
	end
	
	function record:SafeGet(ExclusivePlayer: Player?, LoadAttempts: number?, YieldTime: number?)
		
	end
	
	function record:SafeSet(Data: any, SegmentIndex: number?, SetAttempts: number?, YieldTime: number?)
		
	end
	
	function record:SafeWrite(Data: any, WritingFunction: (CurrentData: any) -> any, LoadAttempts: number?, SetAttempts: number?, YieldTime: number?)
		
	end
	
	function record:AcquireLockSession(OwnerIdentity: string?, Timeout: number?)
		
	end
	
	function record:ReleaseLockSession(OwnerIdentity: string)
		
	end
	
	function record:IsSessionLocked(OwnerIdentity: string)
		
	end
	
	function record:BindExclusiveAccess(ExclusivePlayer: Player)
		
	end
	
	function record:UnbindExclusiveAccess()
		
	end
	
	function record:IsExclusiveAccessBound(ExclusivePlayer: Player)
		
	end
	
	function record:IsPlayerInExclusiveAccess(PlayerThatAssumedExclusive: Player)
		
	end
	
	function record:CreateValidation(ValidationFunction: (PredicateDummy: MyDataValidationDummy) -> any)
		
	end
	
	function record:SmartCleanCache(Interval: number?)
		
	end
	
	return record
end

function MyData.InDataInfo(DataStoreName : string, Scope : string?, Configurations : {any?}) : MyDataInfo
	local _scope = Scope or "global"
	
	local self = setmetatable({}, MyData)
	self._CurrentDataStore = DataStoreService:GetDataStore(DataStoreName, _scope)
	self._CurrentWALDataStore = DataStoreService:GetDataStore(DataStoreName..self.WALDataSuffix, _scope)
	self._CurrentBackupDataStore = DataStoreService:GetDataStore(DataStoreName..self.BackupDataSuffix, _scope)
	self._DataStoreName = DataStoreName
	
	self._MyDataCallbacks = SDictionary.new("string", "table", {
		OnDataLoaded = {},
		OnDataSaved = {},
		OnDataRemoved = {},
		OnDataBinding = {},
		OnDataUnbinding = {},
		OnReleased = {},
		OnDataError = {}
	})
	
	self._DataPredicates = SDictionary.new("string", "table", {}) -- { [Key] = predicateFunction }
		
	self.RequestTimestampLimit = 5
	self.WALEnabled = false
	self.WritingDataAgeEnabled = false
	self.DefaultSaveAttempts = 5
	self.DefaultYieldAttempts = 3
	self.MaxKeyLength = 50
	self.BackupEnabled = true
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
	self.MessagingDebugEnabled = false
	self.DefaultCacheCleanupInterval = 300 -- 300 seconds
	
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

function MyData:GetPlayerData(Key : string, Callbacks : {MyDataCallbackFunctions?}) : MyDataRecord
	if Callbacks then
		for key, value in pairs(Callbacks) do
			local currentFunc = self._MyDataCallbacks:Get(key)
			
			if currentFunc then
				table.insert(currentFunc, value)
			end
		end
	end
	
	return InPlayerData(self, Key)
end

function MyData:GetDataStoreName() : string
	return self._DataStoreName
end

return MyData :: MyData
