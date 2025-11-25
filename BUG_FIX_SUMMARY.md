# Plugin Architecture - Critical Bug Fix

## Problem Summary

The plugin system was experiencing **segmentation faults** during runtime, specifically in the destructor (`eqdestroy`) of plugin contexts. The application would crash immediately when trying to render or update plugins.

## Root Cause

The issue was in how plugin state (`PluginContext[T]`) was being stored and retrieved:

1. **Pointer Storage Without Reference Tracking**: Plugin contexts were stored as raw `pointer` types in a `Table[string, pointer]`
2. **Unsafe Casting**: When retrieving contexts, we cast from `pointer` back to `ref object` (`PluginContext[T]`)
3. **ARC/ORC Lifetime Issues**: Nim's automatic reference counting (ARC/ORC) memory manager didn't track references through raw pointers, leading to:
   - Premature deallocation of plugin contexts
   - Double-free errors when destructors ran
   - Accessing freed memory

### The Bug in Code

**Before (Broken):**
```nim
# In plugin_interface.nim
type
  PluginContext*[T] = ref object
    data*: T
    pluginName*: string

# In PluginAPI
getPluginData*: proc(name: string): pointer
setPluginData*: proc(name: string, data: pointer)

# In backstorie.nim
pluginData*: Table[string, pointer]  # ❌ Lost ref tracking!

# Helpers doing unsafe casts
proc getContext*[T](...): PluginContext[T] =
  let p = api.getPluginData(pluginName)
  result = cast[PluginContext[T]](p)  # ❌ Dangling reference!
```

## Solution

**Use Polymorphic Base Type Instead of Raw Pointers**

We introduced a `RootObj`-based inheritance hierarchy to enable type-safe polymorphic storage:

**After (Fixed):**
```nim
# In plugin_interface.nim
type
  PluginContextBase* = ref object of RootObj
    ## Base type for polymorphic storage - properly tracked by ARC/ORC
    pluginName*: string
  
  PluginContext*[T] = ref object of PluginContextBase
    ## Type-safe derived context
    data*: T

# In PluginAPI
getPluginData*: proc(name: string): PluginContextBase  # ✅ Tracked reference!
setPluginData*: proc(name: string, data: PluginContextBase)

# In backstorie.nim
pluginData*: Table[string, PluginContextBase]  # ✅ Proper ref tracking!

# Safe polymorphic conversion
proc getContext*[T](...): PluginContext[T] =
  let base = api.getPluginData(pluginName)
  result = PluginContext[T](base)  # ✅ Safe downcast
```

## Key Changes

### 1. plugin_interface.nim
- Added `PluginContextBase` as base type inheriting from `RootObj`
- Made `PluginContext[T]` inherit from `PluginContextBase`
- Changed `getPluginData`/`setPluginData` signatures to use `PluginContextBase` instead of `pointer`
- Updated helper procs to use safe polymorphic conversion instead of casting

### 2. backstorie.nim
- Changed `pluginData` from `Table[string, pointer]` to `Table[string, PluginContextBase]`
- Updated `getPluginData`/`setPluginData` implementations to return/accept `PluginContextBase`
- All type conversions now leverage Nim's safe object conversion

## Why This Works

1. **Proper Reference Tracking**: `PluginContextBase` is a `ref object`, so ARC/ORC tracks all references to it
2. **Type Safety**: Nim's type system ensures safe downcasting from base to derived types
3. **No Manual Memory Management**: No need for `GC_ref`/`GC_unref` or other manual reference management
4. **Polymorphic Storage**: `Table[string, PluginContextBase]` can store any `PluginContext[T]` since they all inherit from the base

## Testing

The fix was validated by:
- ✅ Compilation succeeds without errors
- ✅ Application runs without segmentation faults
- ✅ Plugins can create, update, and retrieve state correctly
- ✅ Test script (`test_run.sh`) confirms 2+ seconds of stable execution

## Lessons Learned

### Critical Nim Memory Safety Rules:

1. **Never store `ref object` as raw `pointer` without manual ref counting**
   - ARC/ORC won't track references through `pointer` type
   - Use `RootObj` inheritance for polymorphic storage instead

2. **Avoid `cast` for ref objects**
   - Use safe object conversion `DerivedType(baseInstance)`
   - Nim's type system will validate the conversion

3. **When in doubt, use inheritance over unsafe casts**
   - `ref object of RootObj` provides type-safe polymorphism
   - Properly tracked by Nim's memory manager

## Migration Notes

This fix is **backward compatible** from a plugin perspective:
- Plugin API remains unchanged
- `getContext[T]` and `setContext[T]` have the same signatures
- Existing plugins like `simple_counter.nim` work without modification

## Status

✅ **RESOLVED** - The plugin architecture is now stable and properly manages memory through Nim's reference counting system.
