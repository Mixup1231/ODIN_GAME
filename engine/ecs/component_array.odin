package ecs
import "core:fmt"
import "core:runtime"
import "core:mem"

@private
ComponentArray :: struct {
    components: rawptr,
    type: typeid,
    size: u64,
    keyToIndex: map[KeyType]KeyType,
    indexToKey: map[KeyType]KeyType,
    length: KeyType,
}

@private
componentArrayInit :: proc(using componentArray: ^ComponentArray, $T: typeid) {
    assert(componentArray != nil)

    keyToIndex = make(map[KeyType]KeyType)
    indexToKey = make(map[KeyType]KeyType)
    components, _ = mem.alloc(cast(int)(size_of(T) * MAX_ENTITIES), align_of(T))
    
    return
}

@private
componentArrayDelete :: proc(using componentArray: ^ComponentArray) {
    assert(componentArray != nil)

    delete(keyToIndex)
    delete(indexToKey)
    free(components)
}

@private
componentArrayInsert :: proc(using componentArray: ^ComponentArray, key: KeyType) {
    assert(componentArray != nil)
    assert(!(key in keyToIndex))
    assert(0 <= key && key < MAX_ENTITIES)
    assert(length < MAX_ENTITIES)

    keyToIndex[key] = length
    indexToKey[length] = key
    length += 1
}

@private
componentArrayRemove :: proc(using componentArray: ^ComponentArray, key: KeyType) {
    assert(componentArray != nil)
    assert(key in keyToIndex)
    assert(0 <= key && key < MAX_ENTITIES)
    assert(length > 0)
    
    //need key and index for keeping array packed
    index: KeyType = keyToIndex[key]
    endKey: KeyType = indexToKey[length - 1]

    //copy component at end of array to keep packed
    destination: rawptr = componentArrayGet(componentArray, key)
    source: rawptr = componentArrayGet(componentArray, length - 1)
    runtime.mem_copy(destination, source, cast(int)size)

    //delete key and index of component at end
    delete_key(&keyToIndex, endKey)
    delete_key(&indexToKey, length - 1)

    //update key and index of component that was at the end
    keyToIndex[endKey] = index
    indexToKey[index] = endKey
    length -= 1
}

@private
componentArrayGet :: proc(using componentArray: ^ComponentArray, key: KeyType) -> rawptr {
    assert(key in keyToIndex)
    
    return mem.ptr_offset(cast(^u8)components, cast(u64)key * size)
}
