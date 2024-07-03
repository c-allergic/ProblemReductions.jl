module ProblemReductions

using Graphs, BitBasis
using DocStringExtensions

export @bv_str, StaticElementVector, StaticBitVector, statictrues, staticfalses, onehotv
export Clause, booleans, ¬, ∨, ∧

include("Core.jl")
include("bitvector.jl")
include("sat.jl")
include("spinglass.jl")

end
