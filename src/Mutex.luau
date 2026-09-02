-- OptimizedMutex.lua (Upgraded)

local Mutex = {}
Mutex.__index = Mutex

function Mutex.new() -- creates instance of mutex
	return setmetatable({
		_locked = false, -- flag of current thread is locked
		_owner = nil, -- thread that owns the lock
		_queueHead = 1, -- indicates current thread turns in queue
		_queueTail = 0, -- indicates next free slot in queue
		_queue = {}, -- threads queue, where threads wait for lock and continually wait for locked thread to be unlocked
	}, Mutex)
end

--function Mutex.DualLock(Mutex1, Mutex2)
--	local thread = coroutine.running()
--	if not Mutex1 or not Mutex2 then
--		error("Both Mutex1 and Mutex2 must be valid Mutex instances")
--	end
	
--	if not thread then
--		error("Mutexes must be called from inside a thread/coroutine")
--	end
	
--	if Mutex1._owner == thread or Mutex2._owner == thread then
--		error("Cannot lock the same mutex twice")
--	end
	
--	if Mutex1._locked or Mutex2._locked then
--		Mutex1._queueTail += 1
--		Mutex2._queueTail += 1
--		Mutex1._queue[Mutex1._queueTail] = thread
--		Mutex2._queue[Mutex2._queueTail] = thread
--		return coroutine.yield()
--	end
	
--	Mutex1._locked = true
--	Mutex1._owner = thread
--	Mutex2._locked = true
--	Mutex2._owner = thread
--end

function Mutex:Lock()
	local thread = coroutine.running() -- get current thread
	if not thread then -- this happened when this called outside of a thread
		error("Mutex:Lock() must be called from inside a thread/coroutine")
	end

	-- prevent re-entrant deadlock
	if self._owner == thread then
		error("Mutex:Lock() re-entrant lock detected")
	end

	if self._locked then
		self._queueTail += 1 -- add waiting thread to queue
		self._queue[self._queueTail] = thread -- thread that is waiting for its turn to acquire the lock
		return coroutine.yield() -- yield until resumed by Unlock(), executes next thread in queue
	end

	self._locked = true
	self._owner = thread
end

function Mutex:Unlock()
	local thread = coroutine.running() -- current locked thread

	if not self._locked then
		error("Mutex:Unlock() called while mutex is not locked")
	end

	if self._owner ~= thread then
		error("Mutex:Unlock() called by non-owner coroutine")
	end

	if self._queueHead <= self._queueTail then -- when current thread index in queue was less or equal than tail index or next thread index in queue
		local nextThread = self._queue[self._queueHead] -- moves to next thread with current thread index in queue
		self._queue[self._queueHead] = nil -- remove the locked thread from queue 
		self._queueHead += 1 -- move current thread index in queue forward

		self._owner = nextThread -- set next thread in queue as owner
		task.defer(nextThread) -- execute next thread in queue, but executes late when all spawning threads are executed
	else -- when there is no thread in queue
		self._locked = false -- unlock mutex
		self._owner = nil -- clear owner
		self._queueHead = 1 -- reset queue head or current thread index in queue
		self._queueTail = 0 -- reset queue tail or next free slot in queue
	end
end

function Mutex:Do(callback, ...) -- lazy lock (std::lock_guard equally from C++)
	local args = table.pack(...) -- pack arguments
	
	self:Lock() -- lock current thread
	local ok, result = xpcall(callback, debug.traceback, table.unpack(args)) -- function as current thread
	self:Unlock() -- unlock current thread

	if not ok then
		error(result) -- throws error whatever happened in callback
	end

	return result -- helpfully to give the result of return value from mutex-ed callback
end

return Mutex
