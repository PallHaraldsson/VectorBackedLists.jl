module VectorBackedLists

export list, insert_after!, move_before!, prev, sublist, advance

export start, next, done

struct Node{T}
    value::T    # index into value of the accompanying value
    next::UInt32 # index into nodes of the next node
    prev::UInt32 # index into nodes of the previous node
end

struct VectorBackedList{T,S<:AbstractVector{T}}
    data::S
    nodes::Vector{Node{UInt32}}
    head::UInt32
    tail::UInt32
end

Base.eltype(::Type{VectorBackedList{T,S}}) where {S,T} = T
start(list::VectorBackedList) = list.nodes[list.head].next
next(list::VectorBackedList, state) = (list.data[list.nodes[state].value], list.nodes[state].next)
done(list::VectorBackedList, state) = state == list.tail
function Base.iterate(list::VectorBackedList, state=start(list))
    done(list, state) && return nothing
    return next(list, state)
end

"""
    done(iterable) -> state

Produces an iterator state for which `done(iterable,state) == true`. Cf. to the
C++ end() API.
"""
done(list::VectorBackedList) = list.tail
Base.setindex!(list::VectorBackedList, v, state) = (list.data[list.nodes[state].value] = v)
Base.getindex(list::VectorBackedList, state) = list.data[list.nodes[state].value]

advance(list::VectorBackedList, state) = next(list, state)[2]
Base.length(sl::VectorBackedList) = (n = 0; for x in sl; n += 1; end; n)

function sublist(ls, b, e)
    VectorBackedList{eltype(ls),typeof(ls.data)}(
        ls.data,
        ls.nodes,
        ls.nodes[b].prev,
        e
    )
end

"""
    prev(list, state) -> item, prevstate

Returns the current item from `list` and sets the state to point to the previous
entry. It hold that

```
_, p = prev(list, s)
_, n = next(list, p)
n == s
```
"""
prev(list, state) = (list.data[list.nodes[state].value], list.nodes[state].prev)

"""
Create a list from an indexable container. The list provided a view on the container,
so any mutations realised through calling the list API will be reflected in the
state of the underlying container.
"""
function list(data)
    n = length(data)
    nodes = Vector{Node}(undef, n+2)
    nodes[1] = Node(0,2,0)
    for i in 2:n+1; nodes[i] = Node(UInt(i-1), UInt32(i+1), UInt32(i-1)); end
    nodes[end] = Node(0,0,n+1)
    VectorBackedList{eltype(data), typeof(data)}(data, nodes, UInt32(1), UInt32(n+2))
end

"""
    move_before(list, item, dest)

Move the node pointed to by iterator `item` in fron of iterator `dest`.
"""
function move_before!(list, I, T)

    @assert I != T
    nodes = list.nodes

    # step 1: remove n
    _, P = prev(list,I);
    _, N = next(list,I);
    p = nodes[P]
    n = nodes[N]
    # @assert P == p.idx
    # @assert N == n.idx

    #nodes[P] = Node(p.value, n.idx, p.prev, p.idx)
    nodes[P] = Node(p.value, N, p.prev)
    # nodes[N] = Node(n.value, n.next, p.idx, n.idx)
    nodes[N] = Node(n.value, n.next, P)

    # step 2: reintroduce n
    _, Q = prev(list, T)
    i = nodes[I]
    t = nodes[T]
    q = nodes[Q]
    # @assert Q == q.idx
    # @assert T == t.idx
    # @assert I == i.idx

    nodes[Q] = Node(q.value, I, q.prev)
    nodes[T] = Node(t.value, t.next, I)
    nodes[I] = Node(i.value, T, Q)
    nothing
end

"""
    insert_after!(list, dest, value)

Insert `value` in `list` after the value pointed to by iterator `dest`.
"""
function insert_after!(list::VectorBackedList, T, v)

    data = list.data
    nodes = list.nodes

    push!(data, v)

    _, N = next(list, T)
    t = nodes[T]
    n = nodes[N]

    I = length(nodes)+1
    push!(nodes, Node(length(data), N, T))

    nodes[T] = Node(t.value, I, t.prev)
    nodes[N] = Node(n.value, n.next, I)
    nothing
end


function insert_before!(list::VectorBackedList, T, v)

    data = list.data
    nodes = list.nodes

    push!(data, v)

    P = list.nodes[T].prev
    t = nodes[T]
    p = nodes[P]

    I = length(nodes)+1
    push!(nodes, Node(length(data), T, P))

    nodes[T] = Node(t.value, t.next, I)
    nodes[P] = Node(p.value, I, p.prev)
    nothing
end


Base.push!(list::VectorBackedList, v) = insert_before!(list, done(list), v)


end # module
