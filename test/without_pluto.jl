@testset "Without Pluto" begin
    using PlutoHooks

    ref = @use_ref(1)
    @test ref[] == 1

    x = 2
    @use_effect([x]) do
        ref[] = x
        () -> (ref[] = 9999)
    end
    @test ref[] == 2
    # cleanup never called without pluto ✓
    @test ref[] != 9999


    state, setstate = @use_state(5)
    @test state == 5
    @test_nowarn setstate(99)
    # setstate does nothing without pluto ✓
    @test state == 5


    y = 7
    result = @use_deps([y]) do
        ref2 = @use_ref(1)
        ref2[] = y
    end
    @test result == 7
end
