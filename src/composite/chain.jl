using YaoBase

export ChainBlock, chain

"""
    ChainBlock{N, T} <: CompositeBlock{N, T}

`ChainBlock` is a basic construct tool to create
user defined blocks horizontically. It is a `Vector`
like composite type.
"""
struct ChainBlock{N, T, Blocks <: Tuple} <: CompositeBlock{N, T}
    blocks::Blocks
end

BlockSize(c::ChainBlock) = BlockSize(c.blocks...)
MatrixTrait(c::ChainBlock) = MatrixTrait(c.blocks...)
ChainBlock(blocks::Tuple) = ChainBlock(BlockSize(blocks...), MatrixTrait(blocks...), blocks)
ChainBlock(::NormalSize{N}, ::HasMatrix{N, T}, blocks::Tuple) where {N, T} =
    ChainBlock{N, T, typeof(blocks)}(blocks)
ChainBlock(::UnkownSize, ::MatrixTrait, blocks) =
    ChainBlock{UnkownSize, Any, typeof(blocks)}(blocks)

ChainBlock(blocks::AbstractBlock...) = ChainBlock(blocks)
ChainBlock(c::ChainBlock{N, T, MT}) where {N, T, MT} = ChainBlock{N, T, MT}(c.blocks)

"""
    chain(blocks...)

Return a [`ChainBlock`](@ref) which chains a list of blocks with same
[`nqubits`](@ref) and [`datatype`](@ref). If there is lazy evaluated
block in `blocks`, chain can infer the number of qubits and create an
instance itself.
"""
chain(blocks::AbstractBlock...) = ChainBlock(blocks...)
chain(blocks::Union{AbstractBlock, Function}...) where {N, T} = chain(map(x->parse_block(N, x), blocks)...)
chain(itr) = chain(itr...)

# if not all matrix block, try to put the number of qubits.
chain(n::Int, blocks...) = chain(map(x->parse_block(n, x), blocks)...)
chain(n::Int, itr) = chain(map(x->parse_block(n, x), itr)...)
chain(blocks::Function...) = @λ(n->chain(n, blocks...))

"""
    chain([T=ComplexF64], n)

Return an empty [`ChainBlock`](@ref) which can be used like a list of blocks.
"""
chain(n::Int) = chain(ComplexF64, n)
chain(::Type{T}, n::Int) = chain(AbstractBlock{n, T}[])

"""
    chain()

Return an lambda `n->chain(n)`.
"""
chain() = @λ(n->chain(n))

SubBlocks(c::ChainBlock) = c.blocks
OccupiedLocations(c::ChainBlock) =
    unique(Iterators.flatten(OccupiedLocations(b) for b in subblocks(c)))
chsubblocks(pb::ChainBlock, blocks) = ChainBlock(blocks)

mat(c::ChainBlock) = mat(MatrixTrait(c), c)
mat(::HasMatrix, c::ChainBlock) = prod(x->mat(x), reverse(c.blocks))
mat(::MatrixUnkown, c::ChainBlock) = error("this chain block does not have a matrix representation")

function apply!(r::AbstractRegister, c::ChainBlock)
    for each in c.blocks
        apply!(r, each)
    end
    return r
end

cache_key(c::ChainBlock) = [cache_key(each) for each in c.blocks]

function Base.:(==)(lhs::ChainBlock{N, T}, rhs::ChainBlock{N, T}) where {N, T}
    (length(lhs.blocks) == length(rhs.blocks)) && all(lhs.blocks .== rhs.blocks)
end

Base.copy(c::ChainBlock) = ChainBlock(c)
Base.similar(c::ChainBlock{N, T, MT}) where {N, T, MT} = ChainBlock{N, T}(empty!(similar(c.blocks)))
Base.getindex(c::ChainBlock, index) = getindex(c.blocks, index)
Base.getindex(c::ChainBlock, index::Union{UnitRange, Vector}) = ChainBlock(getindex(c.blocks, index))

Base.adjoint(blk::ChainBlock{N, T, MT}) where {N, T, MT} = ChainBlock{N, T, MT}(map(adjoint, reverse(subblocks(blk))))
Base.lastindex(c::ChainBlock) = lastindex(c.blocks)
## Iterate contained blocks
Base.iterate(c::ChainBlock, st=1) = iterate(c.blocks, st)
Base.length(c::ChainBlock) = length(c.blocks)
Base.eltype(c::ChainBlock) = eltype(c.blocks)
Base.eachindex(c::ChainBlock) = eachindex(c.blocks)

YaoBase.isunitary(c::ChainBlock) = all(isunitary, c.blocks) || isunitary(mat(c))
YaoBase.isreflexive(c::ChainBlock) = (iscommute(c.blocks...) && all(isreflexive, c.blocks)) || isreflexive(mat(c))
YaoBase.ishermitian(c::ChainBlock) = (all(isreflexive, c.blocks) && iscommute(c.blocks...)) || isreflexive(mat(c))