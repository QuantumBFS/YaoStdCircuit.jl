using StatsBase
export UnitaryChannel

# NOTE: this can have a better support in YaoIR directly with StatsBase
# as an compiled instruction, but store the weights is the best solution
# here

"""
    UnitaryChannel(operators[, weights])

Create a unitary channel, optionally weighted from an list of weights.
The unitary channel is defined as below in Kraus representation

```math
ϕ(ρ) = \\sum_i U_i ρ U_i^†
```

!!! note
    when applying a `UnitaryChannel` on the register, a unitary will be sampled
    uniformly or optionally from given weights, then this unitary will be applied
    to the register. 

# Example

```jldoctest
julia> UnitaryChannel([X, Y, Z])
```
"""
struct UnitaryChannel{N, W <: AbstractWeights} <: CompositeBlock{N}
    operators::Vector{AbstractBlock{N}}
    weights::W
end

# TODO: replace this with uweight
# when StatsBase 0.33 is out
function _uweights(n)
    return weights(ones(n))
end

UnitaryChannel(ops::Vector) = UnitaryChannel(ops, _uweights(length(ops)))
UnitaryChannel(it, weights=_uweights(length(it))) = UnitaryChannel(collect(it), weights)

function apply!(r::AbstractRegister, x::UnitaryChannel)
    apply!(r, sample(x.operators, x.weights))
end

function mat(::Type{T}, x::UnitaryChannel) where T
    sum(x.weights .* mat.(T, x.operators))
end

chsubblocks(x::UnitaryChannel{N}, it) where {N} = UnitaryChannel{N}(collect(it), x.weights)
occupied_locs(x::UnitaryChannel) = union(occupied_locs(x.operators)...)

function cache_key(x::UnitaryChannel)
    key = hash(x.weights)
    for each in x.operators
        key = hash(each, key)
    end
    return key
end

function Base.:(==)(lhs::UnitaryChannel{N}, rhs::UnitaryChannel{N}) where N
    return (lhs.weights == rhs.weights) && (lhs.operators == rhs.operators)
end

Base.adjoint(x::UnitaryChannel) = UnitaryChannel(adjoint.(x.operators), x.weights)