# Nim WASM Asynchronous Processing Implementation Policy

This document summarizes the design policy for implementing an asynchronous processing library in Nim for WASM (especially Internet Computer), based on the results of asynchronous processing implementation research in Rust and Motoko.

## 1. Overview and Goals

### 1.1 Implementation Goals
- **API Compatibility**: Provide an API as similar as possible to Nim's standard `asyncdispatch`
- **WASM Optimization**: Efficient implementation specialized for the WebAssembly/IC environment
- **Type Safety**: Detect asynchronous-related errors at compile time
- **Lightweight Implementation**: Custom state machine implementation independent of Asyncify

### 1.2 Target Environment
- **Primary**: Internet Computer (IC) Canister environment (custom runtime, wasmtime-based)
- **Secondary**: WASI (WebAssembly System Interface) standard environment
- **Build Environment**: Clang + WASI SDK (no Emscripten)
- **Execution Environment**: Standalone WASM (no JavaScript calls needed; provided by Dfinity)

### 1.3 Characteristics and Constraints of the ICP Canister Environment
- **Custom WASM Runtime**: Standalone execution with a custom wasmtime-based implementation
- **No JS Bridge Needed**: Dfinity already provides JS-side interfaces
- **No Main Thread Access**: Direct access to the main thread is impossible as it runs as a WASM module in ICP
- **Message-Driven Model**: Each process is triggered by message reception, and responses are automatically sent upon completion of processing
- **`waitFor` Implementation Impossible**: Blocking wait processing cannot be implemented (the ICP system automatically manages the continuation of message processing)
- **Single Message Processing**: Only one message handler executes at a time; when suspended by `await`, it proceeds to other message processing

## 2. Architecture Design

### 2.1 Basic Type Definitions

```nim
# src/asyncwasm/types.nim
type
  # Basic Future type (equivalent to Rust's std::future::Future)
  Future[T] = ref object
    value: T                    # Result value on completion
    error: ref Exception        # Exception on error
    finished: bool              # Completion flag
    callbacks: seq[proc()]      # Callback on completion
    state: FutureState          # Internal state
    
  FutureState = enum
    Pending,      # Running
    Completed,    # Successfully completed
    Failed        # Completed with error
    
  # Executor type
  Executor = ref object
    pendingTasks: seq[Future[void]]         # Tasks waiting to run
    waitingIO: Table[AsyncFD, Future[void]] # I/O waiting tasks
    timers: seq[TimerEntry]                 # Timer tasks
    running: bool                           # Running flag
    
  TimerEntry = object
    deadline: int64           # Expiry time (UNIX timestamp ms)
    future: Future[void]      # Corresponding Future
    
  AsyncFD = distinct int      # Asynchronous file descriptor
```

### 2.2 State Machine-Based Implementation Strategy

Construct state machine based on Rust's Future implementation, with the following policy:

#### 2.2.1 Macro-Based Code Transformation
```nim
# Transform async function to state machine at compile time
macro async*(prc: untyped): untyped =
  # Parse the AST of the procedure body
  # Identify state transition points at await calls
  # Generate code for state preservation in an iterator + closure environment
  result = generateStateMachine(prc)
```

#### 2.2.2 Runtime State Management
```nim
# Each async function is internally implemented as an iterator
iterator asyncProcIterator(): T =
  var localVar1: SomeType
  var localVar2: AnotherType
  
  # State 0: Initial state
  localVar1 = someInitialValue()
  
  # State 1: First await point
  yield AwaitPoint(someAsyncCall())
  
  # State 2: Continuation after await
  localVar2 = processResult(localVar1)
  
  # State N: Completion
  yield FinalResult(localVar2)
```

### 2.3 Executor Design

#### 2.3.1 IC-Specific Executor
Single-task execution model optimized for the Internet Computer environment:

```nim
# src/asyncwasm/ic_executor.nim
type
  ICExecutor = ref object of Executor
    messageContext: ICMessageContext    # IC message context
    callbackRegistry: Table[CallId, Future[void]]  # inter-canister call management
    
proc executeAsync*(executor: ICExecutor, future: Future[T]) =
  ## Start executing Future within IC message handler (non-blocking)
  ## Response is automatically sent by ICP system on completion
  executor.currentTask = future
  
  # Attempt initial execution
  if future.finished:
    # If already completed, return result immediately
    if future.error != nil:
      ic_reply_error(future.error.msg.cstring)
    else:
      ic_reply_success(serialize(future.value))
  else:
    # If not completed, defer to await processing
    # ICP system will continue processing via callbacks
    discard
```

#### 2.3.2 WASI Generic Executor (Reference Implementation)
Generic asynchronous processing in a standard WASI environment (not used in ICP but included for reference):

```nim
# src/asyncwasm/wasi_executor.nim
type
  WASIExecutor = ref object of Executor
    pollSubscriptions: seq[WASIPollSubscription]
    
proc poll*(executor: WASIExecutor, timeout: Duration): int =
  ## WASI poll_oneoffを使用したイベント待機
  ## Note: ICP canister environment uses a custom runtime
  var subscriptions = executor.pollSubscriptions
  var events: array[32, WASIEvent]
  
  let eventCount = wasiPollOneoff(
    addr subscriptions[0], subscriptions.len,
    addr events[0], events.len
  )
  
  for i in 0..<eventCount:
    case events[i].eventType:
    of WASI_EVENTTYPE_FD_READ:
      resumeIOFuture(executor, events[i].fd, IOEvent.Read)
    of WASI_EVENTTYPE_FD_WRITE:
      resumeIOFuture(executor, events[i].fd, IOEvent.Write)
    of WASI_EVENTTYPE_CLOCK:
      processExpiredTimers(executor)
      
  result = eventCount
```

## 3. Core Functionality Implementation

### 3.1 await Implementation
```nim
# src/asyncwasm/await.nim
template await*[T](future: Future[T]): T =
  ## Can only be used inside async functions
  when not declared(currentAsyncContext):
    {.error: "await can only be used inside async procedures".}
  
  if not future.finished:
    # Suspend current Future and register continuation with the target
    registerContinuation(future, currentAsyncContext)
    yield PendingState()
    
  # Processing after completion
  if future.error != nil:
    raise future.error
  future.value
```

### 3.2 Basic Asynchronous Functions
```nim
# src/asyncwasm/primitives.nim
proc sleepAsync*(ms: int): Future[void] =
  ## Future that completes after a specified time
  result = newFuture[void]()
  let deadline = getTime().toUnixFloat() * 1000 + ms.float
  getGlobalExecutor().addTimer(deadline, result)

proc spawnAsync*[T](asyncProc: proc(): Future[T]): Future[T] =
  ## Start an asynchronous task in the background
  result = asyncProc()
  getGlobalExecutor().addTask(result)

proc spawnAndForget*[T](future: Future[T]) =
  ## Execute Future in background (do not wait for result)
  ## In ICP canister environment, results are automatically sent as responses
  let executor = getGlobalExecutor()
  executor.executeAsync(future)

# Note: waitFor cannot be implemented in ICP canister environment
# Blocking waits are impossible due to no main thread access
```

### 3.3 I/O Operations
```nim
# src/asyncwasm/io.nim
proc readAsync*(fd: AsyncFD, buffer: ptr UncheckedArray[uint8], length: int): Future[int] =
  ## Asynchronous read
  result = newFuture[int]()
  
  when defined(ic):
    # Only synchronous I/O supported in IC environment
    try:
      let bytesRead = ic_stable_read(fd.int, buffer, length)
      result.complete(bytesRead)
    except:
      result.fail(getCurrentException())
  else:
    # Asynchronous I/O in WASI environment
    getGlobalExecutor().registerIORead(fd, buffer, length, result)

proc writeAsync*(fd: AsyncFD, buffer: ptr UncheckedArray[uint8], length: int): Future[int] =
  ## Asynchronous write
  result = newFuture[int]()
  
  when defined(ic):
    try:
      let bytesWritten = ic_stable_write(fd.int, buffer, length)
      result.complete(bytesWritten)
    except:
      result.fail(getCurrentException())
  else:
    getGlobalExecutor().registerIOWrite(fd, buffer, length, result)
```

## 4. IC Specific Features

### 4.1 Inter-Canister Call
```nim
# src/asyncwasm/ic_calls.nim
proc callAsync*[T](
  canisterId: Principal, 
  methodName: string,
  args: CandidRecord,
  cycles: int64 = 0
): Future[T] =
  ## Asynchronously call a function of another Canister
  result = newFuture[T]()
  
  let callId = ic_call_new(
    canisterId.toBytes(),
    methodName.cstring,
```

```nim
# ... (Continuation of ic_calls.nim)
# src/asyncwasm/ic_calls.nim

    # Define wrapper procedures for reply and reject
    proc onReplyWrapper(env: uint32) {.exportc.} =
      # Retrieve and decode reply data
      let size = ic0_msg_arg_data_size()
      var buf = newSeq[uint8](size)
      ic0_msg_arg_data_copy(ptrToInt(addr buf[0]), 0, size)
      let decoded = decodeCandidMessage(buf)
      
      # Complete the Future
      result.complete(decoded.values[0].to(T)) # Convert CandidValue to expected type T

    proc onRejectWrapper(env: uint32) {.exportc.} =
      # Retrieve error message and fail the Future
      let err_size = ic0_msg_arg_data_size()
      var err_buf = newSeq[uint8](err_size)
      ic0_msg_arg_data_copy(ptrToInt(addr err_buf[0]), 0, err_size)
      let msg = "IC call failed: " & $err_buf
      result.fail(newException(ICCallError, msg))

  # Set up IC0 call
  # ... (call_new parameters and data append omitted for brevity, similar to ManagementCanister)
  ic0_call_data_append(ptrToInt(addr encodeCandidMessage(args)[0]), encodeCandidMessage(args).len)
  let err = ic0_call_perform()
  if err != 0:
    result.fail(newException(Defect, "call_perform failed with code: " & $err))
```

### 4.2 Reply and Reject
```nim
# src/asyncwasm/ic_reply.nim
proc reply*[T](value: T) {.exportc.} =
  ## Replies to the caller with a Candid-encoded value
  let encoded = encodeCandidMessage(newCandidRecord(value))
  ic0_msg_reply_data_append(ptrToInt(addr encoded[0]), encoded.len)
  ic0_msg_reply()

proc reject*(message: string) {.exportc.} =
  ## Rejects the caller with an error message
  ic0_msg_reject_code(ic0_code_canister_error)
  ic0_msg_reject(message.cstring, message.len)
```

### 4.3 Build System Integration (config.nims)

#### 4.3.1 General Nim WASM Settings
```nim
# config.nims
import std/os

--mm: "orc"                    # ORC memory management (optimized for WASM)
--threads: "off"               # Disable threading (WASM constraint)
--cpu: "wasm32"                # Specify WASM32 architecture
--os: "linux"                  # Specify Linux as base OS
--nomain                       # Disable automatic main function generation
--cc: "clang"                  # Use Clang compiler
--define: "useMalloc"          # Use standard malloc

when defined(release):
  switch("passC", "-Os")       # Size optimization
  switch("passC", "-flto")     # Link-time optimization (compiler)
  switch("passL", "-flto")     # Link-time optimization (linker)
```

#### 4.3.2 IC Specific Build Flags
```nim
# ic0.h header path (IC System API)
let cHeadersPath = "/root/.ic-c-headers"
switch("passC", "-I" & cHeadersPath)
switch("passL", "-L" & cHeadersPath)

# IC WASI polyfill library
let icWasiPolyfillPath = getEnv("IC_WASI_POLYFILL_PATH")
switch("passL", "-L" & icWasiPolyfillPath)
switch("passL", "-lic_wasi_polyfill")

# WASI SDK sysroot settings
let wasiSysroot = getEnv("WASI_SDK_PATH") / "share/wasi-sysroot"
switch("passC", "--sysroot=" & wasiSysroot)
switch("passL", "--sysroot=" & wasiSysroot)
switch("passC", "-I" & wasiSysroot & "/include")

# WASI signal emulation
switch("passC", "-D_WASI_EMULATED_SIGNAL")
switch("passL", "-lwasi-emulated-signal")
```

#### 4.3.3 Impact on Asynchronous Implementation

This setting has the following impact on asynchronous processing implementation:

##### Constraints
- **`--threads: "off"`**: Multithreaded asynchronous operations are unusable
- **`-fno-exceptions`**: Standard exception handling is limited
- **`-nostartfiles`、`--no-entry`**: Custom entry point is required

##### Advantages
- **No Emscripten**: No Asyncify overhead
- **WASI polyfill**: WASI API available in IC environment
- **ic0 System API**: Direct access to IC-specific features
- **Static Linking**: Self-contained modules

#### 4.3.4 Reflection in Implementation Strategy

```nim
# Lightweight state machine implementation not using Emscripten's Asyncify
type
  AsyncState = enum
    StateInit,     # Initial state
    StateWaiting,  # Waiting for await
    StateResumed,  # After resumption
    StateComplete  # Completed

  AsyncContext[T] = ref object
    state: AsyncState
    continuation: proc()  # Continuation process
    result: T
    error: ref Exception
    
# Direct use of WASI poll_oneoff
proc wasiPoll(subscriptions: ptr WASISubscription, 
              events: ptr WASIEvent): int =
  {.importc: "poll_oneoff", header: "wasi/api.h".}

# Integration with IC System API
proc icSystemCall(method: cstring, args: cstring): cstring =
  {.importc: "ic0_call_simple", header: "ic0.h".}
```

This design enables a lightweight asynchronous processing library optimized for ICP, independent of Emscripten's Asyncify.

## 5. Optimization Strategy

### 5.1 Compile-time Optimization
```nim
# Example of macro optimization
macro optimizeAsync*(body: untyped): untyped =
  # Combining consecutive awaits
  # Removing unnecessary state transitions
  # Identifying inlinable functions
  result = optimizeAsyncAST(body)

# Usage example
proc complexAsyncProc(): Future[int] {.async.} =
  optimizeAsync:
    let a = await simpleCall1()
    let b = await simpleCall2()
    result = a + b
```

### 5.2 Memory Efficiency
```nim
# Using object pool
type
  FuturePool[T] = object
    available: seq[Future[T]]
    created: int
    
proc borrowFuture*[T](pool: var FuturePool[T]): Future[T] =
  if pool.available.len > 0:
    result = pool.available.pop()
    result.reset()
  else:
    result = Future[T](state: Pending)
    inc pool.created

proc returnFuture*[T](pool: var FuturePool[T], future: Future[T]) =
  pool.available.add(future)
```

### 5.3 Code Size Optimization
```nim
# Reducing common code with templates
template commonAsyncSetup*(futureVar: untyped): untyped =
  let executor = getGlobalExecutor()
  futureVar = newFuture[type(futureVar[])]()
  
template commonAsyncCleanup*(futureVar: untyped): untyped =
  if futureVar.error != nil:
    raise futureVar.error
```

## 6. Error Handling and Debugging

### 6.1 Structured Exception Handling
```nim
# src/asyncwasm/exceptions.nim
type
  AsyncException* = object of CatchableError
    futureStack*: seq[string]  # Asynchronous stack trace
    
  TimeoutError* = object of AsyncException
  ChannelClosedError* = object of AsyncException
  ICCallError* = object of AsyncException
    callId*: string
    canisterId*: Principal

proc captureAsyncStack(): seq[string] =
  # Get current async function call stack
  result = []
  for frame in getCurrentAsyncFrames():
    result.add(frame.procName & ":" & $frame.line)
```

### 6.2 Debugging Support
```nim
# Detailed logs in debug mode
when defined(asyncDebug):
  template debugAsyncLog*(msg: string) =
    echo "[ASYNC] ", msg, " at ", instantiationInfo()
else:
  template debugAsyncLog*(msg: string) = discard

# Performance measurement
type
  AsyncProfiler* = object
    taskCounts*: Table[string, int]
    totalTimes*: Table[string, float]
    
proc profileAsync*[T](name: string, future: Future[T]): Future[T] =
  when defined(asyncProfile):
    let start = cpuTime()
    result = future
    result.addCallback proc() =
      let elapsed = cpuTime() - start
      getGlobalProfiler().record(name, elapsed)
  else:
    result = future
```

## 7. Testing Strategy

### 7.1 Unit Tests
```nim
# tests/asyncwasm/test_futures.nim
import unittest
import ../src/asyncwasm

suite "Basic Future Operations":
  test "Future completion":
    proc testProc(): Future[int] {.async.} =
      return 42
      
    # Note: waitFor cannot be used in ICP canister environment
    # Test with callbacks instead
    let future = testProc()
    future.addCallback proc() =
      check future.finished
      check future.value == 42
    
  test "Future with await":
    proc asyncAdd(a, b: int): Future[int] {.async.} =
      await sleepAsync(10)  # Wait 10ms
      return a + b
      
    # Test for ICP canister environment
    let future = asyncAdd(5, 3)
    future.addCallback proc() =
      check future.finished
      check future.value == 8
```

### 7.2 Integration Tests
```nim
# tests/asyncwasm/test_ic_integration.nim
proc testICCall(): Future[string] {.async.} =
  let response = await callAsync[string](
    principal("rdmx6-jaaaa-aaaaa-aaadq-cai"),
    "greet",
    %* {"name": "World"}
  )
  return response

when defined(ic):
  suite "IC Integration Tests":
    test "inter-canister call":
      # Test for ICP canister environment (no waitFor)
      let future = testICCall()
      future.addCallback proc() =
        check future.finished
        check future.value.contains("Hello, World")
```

## 8. Documentation and API Reference

### 8.1 API Compatibility Map
| Nim Standard asyncdispatch | This Implementation | Remarks |
|-------------------|-------|------|
| `asyncCheck` | `spawnAsync` | Background execution of tasks |
| `waitFor` | **Not Implemented** | No main thread access in ICP canister environment |
| `sleepAsync` | `sleepAsync` | Fully compatible |
| `asyncdispatch.runForever` | **Not Implemented** | Not needed in ICP due to message-driven model |
| Newly Added | `spawnAndForget` | Asynchronous execution in ICP (results automatically sent as responses) |

### 8.2 Usage Example Document
```nim
# Basic usage example (for ICP canister environment)
proc example1(): Future[string] {.async.} =
  ## Used as an update method
  echo "Processing started"
  await sleepAsync(1000)  # Wait 1 second
  return "Completed"  # Result automatically sent as response

# Example of using IC-specific features
proc example2(): Future[void] {.async.} =
  ## Used as a query method
  let balance = await callAsync[nat](
    ic.managementCanister,
    "canister_status",
    %* {"canister_id": ic.id()}
  )
  echo "Current cycles: ", balance

# Example of error handling
proc example3(): Future[string] {.async.} =
  try:
    let result = await riskyAsyncOperation()
    return result
  except AsyncException as e:
    echo "Async error: ", e.msg
    echo "Stack: ", e.futureStack
    raise

# Example of entry point usage in ICP
```
