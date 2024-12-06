"""
    AbstractProblem

The abstract base type of computational problems.

### Required interfaces
- [`variables`](@ref), the degrees of freedoms in the computational problem.
- [`flavors`](@ref), the flavors (domain) of a degree of freedom.
- [`energy`](@ref), energy the energy (the lower the better) of the input configuration.
- [`problem_size`](@ref), the size of the computational problem. e.g. for a graph, it could be `(n_vertices=?, n_edges=?)`.

### Optional interfaces
- [`num_variables`](@ref), the number of variables in the computational problem.
- [`num_flavors`](@ref), the number of flavors (domain) of a degree of freedom.
- [`findbest`](@ref), find the best configurations of the input problem.
"""
abstract type AbstractProblem end

"""
    ConstraintSatisfactionProblem{T} <: AbstractProblem

The abstract base type of constraint satisfaction problems. `T` is the type of the local energy of the constraints.

### Required interfaces
- [`hard_constraints`](@ref), the specification of the hard constraints. Once the hard constraints are violated, the energy goes to infinity.
- [`is_satisfied`](@ref), check if the hard constraints are satisfied.

- [`soft_constraints`](@ref), the specification of the energy terms as soft constraints, which is associated with weights.
- [`local_energy`](@ref), the local energy for the constraints.
- [`weights`](@ref): The weights of the soft constraints.
- [`set_weights`](@ref): Change the weights for the `problem` and return a new problem instance.
"""
abstract type ConstraintSatisfactionProblem{T} <: AbstractProblem end

"""
$TYPEDEF

A hard constraint on a [`ConstraintSatisfactionProblem`](@ref).

### Fields
- `variables`: the indices of the variables involved in the constraint.
- `specification`: the specification of the constraint.
"""
struct HardConstraint{ST}
    variables::Vector{Int}
    specification::ST
end
num_variables(spec::HardConstraint) = length(spec.variables)

"""
$TYPEDEF

A soft constraint on a [`ConstraintSatisfactionProblem`](@ref).

### Fields
- `variables`: the indices of the variables involved in the constraint.
- `specification`: the specification of the constraint.
- `weight`:  the weight of the constraint.
"""
struct SoftConstraint{WT, ST}
    variables::Vector{Int}
    specification::ST
    weight::WT
end
num_variables(spec::SoftConstraint) = length(spec.variables)

######## Interfaces for computational problems ##########
"""
    weights(problem::ConstraintSatisfactionProblem) -> Vector

The weights of the constraints in the problem.
"""
function weights end

"""
    set_weights(problem::ConstraintSatisfactionProblem, weights) -> ConstraintSatisfactionProblem

Change the weights for the `problem` and return a new problem instance.
"""
function set_weights end

"""
    is_weighted(problem::ConstraintSatisfactionProblem) -> Bool

Check if the problem is weighted. Returns `true` if the problem has non-unit weights.
"""
function is_weighted(problem::ConstraintSatisfactionProblem)
    hasmethod(weights, Tuple{typeof(problem)}) && !(weights(problem) isa UnitWeight)
end

"""
    problem_size(problem::AbstractProblem) -> NamedTuple

The size of the computational problem, which is problem dependent.
"""
function problem_size end

"""
    variables(problem::AbstractProblem) -> Vector

The degrees of freedoms in the computational problem. e.g. for the maximum independent set problems, they are the indices of vertices: 1, 2, 3...,
while for the max cut problem, they are the edges.
"""
variables(c::AbstractProblem) = 1:num_variables(c)

"""
    num_variables(problem::AbstractProblem) -> Int

The number of variables in the computational problem.
"""
function num_variables end

"""
    weight_type(problem::AbstractProblem) -> Type

The data type of the weights in the computational problem.
"""
weight_type(gp::AbstractProblem) = eltype(weights(gp))

"""
    flavors(::Type{<:AbstractProblem}) -> Vector

Returns a vector of integers as the flavors (domain) of a degree of freedom.
"""
flavors(::GT) where GT<:AbstractProblem = flavors(GT)


"""
    flavor_to_logical(::Type{T}, flavor) -> T

Convert the flavor to a logical value.
"""
function flavor_to_logical(::Type{T}, flavor) where T
    flvs = flavors(T)
    @assert length(flvs) == 2 "The number of flavors must be 2, got: $(length(flvs))"
    if flavor == flvs[1]
        return false
    elseif flavor == flvs[2]
        return true
    else
        error("The flavor must be one of the flavors $(flvs), got: $(flavor)")
    end
end

"""
    num_flavors(::Type{<:AbstractProblem}) -> Int

Returns the number of flavors (domain) of a degree of freedom.
"""
num_flavors(::GT) where GT<:AbstractProblem = length(flavors(GT))

"""
    energy(problem::AbstractProblem, config) -> Real

Energy of the `problem` given the configuration `config`.
The lower the energy, the better the configuration.
"""
function energy end

# energy interface
energy(problem::AbstractProblem, config) = first(energy_eval_byid_multiple(problem, (config_to_id(problem, config),)))
function energy_eval_byid_multiple(problem::ConstraintSatisfactionProblem{T}, ids) where T
    terms = energy_terms(problem)
    return Iterators.map(ids) do id
        energy_eval_byid(terms, id)
    end
end
function config_to_id(problem::AbstractProblem, config)
    flvs = flavors(problem)
    map(c -> findfirst(==(c), flvs), config)
end
function id_to_config(problem::AbstractProblem, id)
    flvs = flavors(problem)
    map(i -> flvs[i], id)
end

struct EnergyTerm{LT, N, F, T}
    variables::Vector{LT}
    flavors::NTuple{N, F}
    strides::Vector{Int}
    energies::Vector{T}
end
function Base.show(io::IO, term::EnergyTerm)
    println(io, """EnergyTerm""")
    entries = []
    sizes = repeat([length(term.flavors)], length(term.variables))
    for (idx, energy) in zip(CartesianIndices(Tuple(sizes)), term.energies)
        push!(entries, [getindex.(Ref(term.flavors), idx.I)..., energy])
    end
	pretty_table(io, transpose(hcat(entries...)); header=[string.(term.variables)..., "energy"])
	return nothing
end
Base.show(io::IO, ::MIME"text/plain", term::EnergyTerm) = show(io, term)

energy_terms(problem::ConstraintSatisfactionProblem{T}) where T = energy_terms(T, problem)
function energy_terms(::Type{T}, problem::ConstraintSatisfactionProblem) where T
    vars = variables(problem)
    flvs = flavors(problem)
    nflv = length(flvs)
    terms = EnergyTerm{eltype(vars), length(flvs), eltype(flvs), T}[]
    for constraint in hard_constraints(problem)
        sizes = [nflv for _ in constraint.variables]
        energies = map(CartesianIndices(Tuple(sizes))) do idx
            is_satisfied(typeof(problem), constraint, getindex.(Ref(flvs), idx.I)) ? zero(T) : energy_max(T)
        end
        strides = [nflv^i for i in 0:length(constraint.variables)-1]
        push!(terms, EnergyTerm(constraint.variables, flvs, strides, vec(energies)))
    end
    for (i, constraint) in enumerate(soft_constraints(problem))
        sizes = [nflv for _ in constraint.variables]
        energies = map(CartesianIndices(Tuple(sizes))) do idx
            T(local_energy(typeof(problem), constraint, getindex.(Ref(flvs), idx.I)))
        end
        strides = [nflv^i for i in 0:length(constraint.variables)-1]
        push!(terms, EnergyTerm(constraint.variables, flvs, strides, vec(energies)))
    end
    return terms
end

Base.@propagate_inbounds function energy_eval_byid(terms::AbstractVector{EnergyTerm{LT, N, F, T}}, config_id) where {LT, N, F, T}
    sum(terms) do term
        k = 1
        for (stride, var) in zip(term.strides, term.variables)
            k += stride * (config_id[var]-1)
        end
        term.energies[k]
    end
end

"""
$TYPEDSIGNATURES

Return the log2 size of the configuration space of the problem.
"""
function configuration_space_size(problem::AbstractProblem)
    return log2(num_flavors(problem)) * num_variables(problem)
end

"""
    findbest(problem::AbstractProblem, method) -> Vector

Find the best configurations of the `problem` using the `method`.
"""
function findbest end

"""
    UnitWeight <: AbstractVector{Int}

The unit weight vector of length `n`.
"""
struct UnitWeight <: AbstractVector{Int}
    n::Int
end
Base.getindex(::UnitWeight, i) = 1
Base.size(w::UnitWeight) = (w.n,)

"""
    soft_constraints(problem::AbstractProblem) -> Vector{SoftConstraint}

The energy terms of the problem. Each term is associated with weights.
"""
function soft_constraints end

"""
    hard_constraints(problem::AbstractProblem) -> Vector{HardConstraint}

The hard constraints of the problem. Once the hard constraints are violated, the energy goes to infinity.
"""
function hard_constraints end

macro nohard_constraints(problem)
    esc(quote
        function $ProblemReductions.hard_constraints(problem::$(problem))
            return HardConstraint{Nothing}[]
        end
    end)
end

"""
    is_satisfied(::Type{<:ConstraintSatisfactionProblem}, constraint::HardConstraint, config) -> Bool

Check if the `constraint` is satisfied by the configuration `config`.
"""
function is_satisfied end

"""
    local_energy(::Type{<:ConstraintSatisfactionProblem{T}}, constraint::SoftConstraint, config) -> T

The local energy of the `constraint` given the configuration `config`.
"""
function local_energy end

# the maximum energy for the local energy function, this is used to avoid overflow of integer energy
energy_max(::Type{T}) where T = typemax(T)
energy_max(::Type{T}) where T<:Integer = round(T, sqrt(typemax(T)))

include("SpinGlass.jl")
include("Circuit.jl")
include("Coloring.jl")
include("Satisfiability.jl")
include("SetCovering.jl")
include("MaxCut.jl")
include("IndependentSet.jl")
include("VertexCovering.jl")
include("SetPacking.jl")
include("DominatingSet.jl")
include("QUBO.jl")
include("Factoring.jl")
include("Matching.jl")
include("MaximalIS.jl")
include("Paintshop.jl")
