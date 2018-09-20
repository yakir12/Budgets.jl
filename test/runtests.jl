using Budgets, Test, Dates

@testset "single" begin
    e1 = Event(Date(1001, 1, 1), "e", 2, Money(10))
    d1 = Event("d", Money(-5))
    p1 = Event(Date(999,9,9), Money(-5))
    b = Budget(Percentile(10))
    add!(b, e1)
    add!(b, d1)
    add!(b, p1)
    @test taxable(b) == Money(20)
    @test tax(b) == Money{Float64}(2)
    @test balance(b) == Money{Float64}(12)
    @testset "mutliple" begin
        e2 = Event(Date(1000, 1, 1), "r", 3, Money(15))
        e3 = Event(Date(1002, 1, 1), "t", 6, Money(34.5))
        add!(b, e2, e3)
        @test expenses(b) == [e2, e1, e3]
        @test deductions(b) == [d1]
        @test payments(b) == [p1]
    end
end

@testset "in" begin 
    events = ["e: , e1, 1, 44.4", "e: 1-1-1, e1, 11, 44.4", "d: yea, -44.4", "p: 2014-11-11, -44.4"]
    b = Budget(Percentile(14))
    add!(b, define_event.(events)...)
    @test balance(b) == Money(12*44.4*1.14-44.4-44.4)
    @testset "out" begin
        @test print(b) == "January 1, 1 & e1 & 11 & 44.4 sek & 488.4 sek \\\\\n & e1 & 1 & 44.4 sek & 44.4 sek \\\\\n\\hline\n & Total & & & 532.8 sek\\\\\n & VAT (14\\%) & & &74.59 sek\\\\\n & yea & & & -44.4 sek\\\\\nNovember 11, 2014 & Payment & & & -44.4 sek\\\\\n& Balance due & & & 518.59 sek\\\\"
    end
end

