__precompile__()

module Budgets

using StringBuilders, Formatting, Missings, Match, Dates

import Base:*, +, -, print

export Percentile, Money, Event, Expense, Deduction, Payment, Budget, add!, expenses, deductions, payments, taxable, tax, nontaxable, balance, define_event

struct Percentile{T<:Real}
    p::T 
end

struct Money{T<:Real}
    value::T
end

*(m::Money, x::Int) = Money(m.value*x)
*(p::Percentile, x::Money) = Money(p.p/100*x.value)
*(x::Money, p::Percentile) = p*x
+(m::Money, x::Money) = Money(m.value + x.value)

abstract type Event end

struct Expense <: Event
    date::Union{Missing, Date}
    description::String
    units::Int
    rate::Money
    sum::Money
    function Expense(date, description, units, rate::Money)
        @assert units > 0 "units must be positive"
        @assert rate.value > 0 "expense must be positive"
        new(date, description, units, rate, rate*units)
    end
end

struct Deduction <: Event
    description::String
    sum::Money
    function Deduction(description, sum)
        @assert sum.value < 0 "deduction must be negative"
        new(description, sum)
    end
end

struct Payment <: Event
    date::Date
    sum::Money
    function Payment(date, sum)
        @assert sum.value < 0 "payment must be negative"
        new(date, sum)
    end
end

+(x::Money, event::Event) = x + event.sum

Event(a, b, c, d) = Expense(a, b, c, d)
Event(a, b) = Deduction(a, b)
Event(a::Date, b) = Payment(a, b)

struct Budget
    moms::Percentile
    events::Vector{Event}
    Budget(moms::Percentile) = new(moms, Event[])
end

add!(b, x...) = push!(b.events, x...)

expenses(b) = sort(filter(x -> x isa Expense, b.events), by = x -> x.date)

deductions(b) = filter(x -> x isa Deduction, b.events)

payments(b) = sort(filter(x -> x isa Payment, b.events), by = x -> x.date)

nonexpenses(b) = filter(x -> !isa(x, Expense), b.events)

taxable(b) = reduce(+, expenses(b), init = Money(0))

tax(b) = taxable(b)*b.moms

balance(b) = taxable(b) + tax(b) + reduce(+, nonexpenses(b), init = Money(0))

# in

function define_event(l::String)
    a = match(r"^([edp]):(.*)"i, l)
    event = first(a.captures)
    fields = strip.(split(last(a.captures), ","))
    return @match event begin 
        "e" => begin
            a, b, c, d = fields
            Event(isempty(a) ? missing : Date(a), b, parse(Int, c), Money(parse(Float64, d)))
        end
        "d" => begin
            a, b = fields
            Event(a, Money(parse(Float64, b)))
        end
        "p" => begin
            a, b = fields
            Event(Date(a), Money(parse(Float64, b)))
        end
    end
end

# out

_format(x) = format(x, commas = true, precision = 2 , stripzeros = true)

my_format(x::Number) = _format(x)
my_format(x::String) = x
my_format(x::Missing) = ""
my_format(x::Date) = Dates.format(x, "U d, Y")
function my_format(x::Percentile) 
    a = my_format(x.p)
    return "$a\\%"
end
function my_format(x::Money) 
    a = my_format(x.value)
    return "$a sek"
end
#=function format2md(x::Money) 
    a = my_format(x.value)
    return "$a sek"
end=#
# format2md(x) = my_format(x)

function print(b::Budget)
    o = StringBuilder()
    for expense in expenses(b)
        for field in [:date, :description, :units, :rate]
            append!(o, my_format(getfield(expense, field)), " & ")
        end
        append!(o, my_format(expense.sum), " \\\\\n")
    end

    append!(o, "\\hline\n & Total & & & ", my_format(taxable(b)), "\\\\\n & VAT (", my_format(b.moms), ") & & &", my_format(tax(b)), "\\\\\n")

    for deduction in deductions(b)
        append!(o, " & ", deduction.description, " & & & ", my_format(deduction.sum), "\\\\\n")
    end

    for payment in payments(b)
        append!(o, my_format(payment.date), " & Payment & & & ", my_format(payment.sum), "\\\\\n")
    end

    append!(o, "& Balance due & & & ", my_format(balance(b)), "\\\\")
    return String(o)
end

end # module
