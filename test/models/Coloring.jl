using Test, ProblemReductions, Graphs

# create a graph

@testset "coloring" begin
    # constructor function
    @test flavors(Coloring{3}) == (0, 1, 2)
    @test num_flavors(Coloring{3}) == 3
    
    g = SimpleGraph(4)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    add_edge!(g, 3, 4)
    add_edge!(g, 4, 1)
    c = Coloring{3}(g, UnitWeight(nv(g)))
    @test set_weights(c, [1, 2, 2, 1]) == Coloring{3}(g, [1, 2, 2, 1])
    c2 = Coloring{3}(g)
    @test c2 == c
    @test c.graph == g && c.weights isa UnitWeight
    @test variables(c) == [1, 2, 3, 4]
    @test problem_size(c) == (; num_vertices=4, num_edges=4)

    # weights interface
    @test ProblemReductions.weights(c) == UnitWeight(nv(g))
    @test ProblemReductions.set_weights(c, [1, 2, 2, 1]) == Coloring{3}(g, [1, 2, 2, 1])

    # solution_size
    solution = solution_size(c,[0, 1, 2, 0])
    @test solution.size == 1
    @test solution.is_valid
    @test is_vertex_coloring(g, [0, 1, 2, 0]) == false
end

