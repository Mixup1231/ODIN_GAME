package spatial
import mm "../mars_math"

QuadTreeData :: struct($T: typeid) {
    data: ^T,
    point: mm.Vec2f
}

QuadTreeNode :: struct($T: typeid) {
    bounds: AABB,
    data: [dynamic]QuadTreeData(T),
    leaf: bool,
    capacity: u32,
    maxCapacity: u32,
    depth: u32,
    maxDepth: u32,
    divided: bool,
    nodes: [4]^QuadTreeNode(T),
}

@private
quadTreeNodeCreate :: proc(
    $T: typeid, capacity: u32, maxDepth: u32, depth: u32 = 0, bounds: AABB
) -> (
    result: ^QuadTreeNode(T)
) {
    result = new(QuadTreeNode(T))
    result.bounds = bounds
    result.leaf = true
    result.maxCapacity = capacity
    result.maxDepth = maxDepth
    result.depth = depth
    return
}

@private
quadTreeNodeFree :: proc(using root: ^QuadTreeNode($T)) {
    assert(root != nil)

    if leaf {
        return
    }

    for node in nodes {
        if node != nil {
            quadTreeNodeFree(node)
            free(node)
        }
    }
}

@(private)
quadTreeNodeSubdivide :: proc(
    using node: ^QuadTreeNode($T)
) {
    using AabbDivisions

    assert(node != nil)

    if divided {
        return
    }

    divisions: [4]AABB = aabbSubdivide(bounds)
    for _, i in nodes {
        nodes[i] = quadTreeNodeCreate(T, maxCapacity, maxDepth, depth + 1, divisions[i])
    }

    divided = true
}

quadTreeCreate :: proc(
    $T: typeid, capacity: u32, maxDepth: u32, bounds: AABB
) -> (
    result: ^QuadTreeNode(T)
) {
    result = quadTreeNodeCreate(T, capacity, maxDepth, 0, bounds)
    return
}

quadTreeFree :: proc(using root: ^QuadTreeNode($T)) {
    assert(root != nil)

    quadTreeNodeFree(root)
    free(root)
}

quadTreeInsert :: proc(
    using root: ^QuadTreeNode($T), point: mm.Vec2f, value: ^T
) {
    assert(root != nil && value != nil)
    
    if !pointInAabb(point, bounds) {
        return
    }

    if capacity >= maxCapacity { // at capacity
        if !divided && depth < maxDepth { //subdivide if not at max depth
            quadTreeNodeSubdivide(root)
            depth += 1
            leaf = false
            for node in nodes {
                for element in data {
                    quadTreeInsert(node, element.point, element.data)
                }
            }
        }
        if divided { //if divided continue inserting and return
            for node in nodes {
                quadTreeInsert(node, point, value)
            }
            return
        }
    }
    
    //this is a leaf node that contains point, insert
    append_elem(&data, QuadTreeData(T){value, point})
    capacity += 1
}

quadTreeGet :: proc(
    using root: ^QuadTreeNode($T), target: AABB, result: ^[dynamic]^T, checkDuplicates: bool = false
) {
    assert(root != nil)

    if !aabbInAabb(target, bounds) {
        return
    }

    if leaf {
        for element in data {
            if pointInAabb(element.point, target) {
                if !checkDuplicates {
                    append_elem(result, element.data)
                } else {
                    found: bool = false
                        
                    for &point in result {
                        if point == element.data {
                            found = true
                        }
                    }
                    if !found {
                        append_elem(result, element.data)
                    }
                }
            }
        }
    } else {
        for node in nodes {
            if node != nil {
                quadTreeGet(node, target, result)
            }
        }
    }
}

quadTreeClear :: proc(using root: ^QuadTreeNode($T)) {
    assert(root != nil)

    for node in nodes {
        if node != nil {
            quadTreeNodeFree(node)
            free(node)
        }
    }

    depth = 0
    capacity = 0
    leaf = true
    divided = false
    clear_dynamic_array(&data)
}
