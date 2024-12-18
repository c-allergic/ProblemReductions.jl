using Test, ProblemReductions

@testset "setpacking" begin
    # construct two inequivalent sets
    sets01 = [[1, 2, 5], [1, 3], [2, 4], [3, 6], [2, 3, 6]]
    sets02 = [[1, 3], [1, 2, 5], [2, 4], [3, 6], [2, 3, 6]]

    # construct corresponding SetPacking problems
    SP_01 = SetPacking(sets01)
    @test set_weights(SP_01, [1, 2, 2, 1, 1]) == SetPacking([[1, 2, 5], [1, 3], [2, 4], [3, 6], [2, 3, 6]], [1, 2, 2, 1, 1])
    SP_02 = SetPacking(sets02)
    @test !(SP_01 == SP_02)
    @test SP_01 == SetPacking([[1, 2, 5], [1, 3], [2, 4], [3, 6], [2, 3, 6]])
    @test problem_size(SP_01) == (; num_elements = 6, num_sets = 5)
    @test problem_size(SP_02) == (; num_elements = 6, num_sets = 5)

    # variables
    @test variables(SP_01) == [1, 2, 3, 4, 5]
    @test num_variables(SP_01) == 5
    @test flavors(SetPacking) == (0, 1)

    # solution_size
    # a Positive examples
    cfg01 = [1, 0, 0, 1, 0]
    @test solution_size(SP_01, cfg01) == SolutionSize(2, true)
    @test is_set_packing(SP_01, cfg01) == true

    # a Negative example
    cfg02 = [1, 0, 1, 1, 0]
    @test !solution_size(SP_01, cfg02).is_valid
    @test is_set_packing(SP_01, cfg02) == false

    # test findbest function
    cfg03 = [0, 1, 1, 0, 0]
    cfg04 = [0, 0, 1, 1, 0]
    @test Set( findbest(SP_01, BruteForce()) ) == Set( [cfg01, cfg03, cfg04] ) # "1" is superior to "0"
end