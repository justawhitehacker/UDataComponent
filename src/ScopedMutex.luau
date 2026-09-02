local ScopedMutex = {}
ScopedMutex.__index = ScopedMutex

export type Mutex = {
	new: (Mutex: any) -> ScopedMutex
}

export type ScopedMutex = {
	Acquire: (self: ScopedMutex, key: string) -> (),
	Release: (self: ScopedMutex, key: string) -> (),
	IsLocked: (self: ScopedMutex, key: string) -> boolean,
	Do: (self: ScopedMutex, key: string, func: () -> ()) -> ()
}

function ScopedMutex.new(mutex) : ScopedMutex
	local self = setmetatable({
		_keys = {}, -- { Mutex = mutex, refcount = number },
		_class = mutex
	}, ScopedMutex)
	return self :: ScopedMutex
end

function ScopedMutex:Acquire(key)
	local scopeMutex = self._keys[key]
	if not scopeMutex then
		scopeMutex = { Mutex = self._class.new(), refcount = 0 }
		self._keys[key] = scopeMutex
	end
	
	scopeMutex.refcount += 1
	scopeMutex.Mutex:Lock()
	
	return true
end

function ScopedMutex:Release(key)
	local scopeMutex = self._keys[key]
	if not scopeMutex then
		error("Scoped mutex: trying to release a mutex that was not acquired")
	end
	
	scopeMutex.Mutex:Unlock()

	scopeMutex.refcount -= 1
	if scopeMutex.refcount <= 0 then
		self._keys[key] = nil
	end
end

function ScopedMutex:IsLocked(key)
	return self._keys[key] and self._keys[key].refcount > 0
end

function ScopedMutex:Do(key, func, ...)
	local args = table.pack(...)
		
	self:Acquire(key)
	local ok, result = xpcall(func, debug.traceback, table.unpack(args, 1, args.n))
	self:Release(key)
	
	if not ok then
		warn("Scoped mutex: error in function: " .. tostring(result))
		
		return false, result
	end
	
	return true, result
end

return ScopedMutex :: Mutex
