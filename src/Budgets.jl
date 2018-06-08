__precompile__()

module Budgets

using StringBuilders, Formatting, Missings, Rematch

import Base:*, +, -, print

export Percentile, Money, Event, Expense, Deduction, Payment, Budget, add!, expenses, deductions, payments, taxable, tax, nontaxable, balance, define_event

struct Percentile{T<:Real}
    p::T 
end

struct Money{T<:Real}
    value::T
end

*(m::Money, x::Int) = Money(m.value*x)
*(x::Int, m::Money) = m*x
*(p::Percentile, x::Money) = Money(p.p/100*x.value)
*(x::Money, p::Percentile) = p*x
+(m::Money, x::Money) = Money(m.value + x.value)
-(m::Money, x::Money) = Money(m.value - x.value)

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

taxable(b) = reduce(+, Money(0), expenses(b))

tax(b) = taxable(b)*b.moms

balance(b) = taxable(b) + tax(b) + reduce(+, Money(0), nonexpenses(b))

# in

function define_event(l::String)
    a = match(r"^([edp]):(.*)"i, l)
    event = first(a.captures)
    fields = strip.(split(last(a.captures), ","))
    return @match event begin 
        "e" => begin
            a, b, c, d = fields
            Event(isempty(a) ? missing : Date(a), b, parse(Int, c), Money(parse(d)))
        end
        "d" => begin
            a, b = fields
            Event(a, Money(parse(b)))
        end
        "p" => begin
            a, b = fields
            Event(Date(a), Money(parse(b)))
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


    #=function printmd(b::Budget)
    nexpenses = length(b.expenses)
    ndeductions = length(b.deductions)
    npayments = length(b.payments)
    a = ["" for i = 1:nexpenses + ndeductions + 4 + npayments, j = 1:4]
    a[1,:] = ["Description", "Units", "Rate", "Amount"]
    for (r, expense) in enumerate(b.expenses), (c, field) in enumerate([:description, :units, :price, :sum])
    a[r + 1, c] = my_format(getfield(expense, field))
    end
    a[nexpenses + 2,3] = "Total"
    a[nexpenses + 2,4] = my_format(b.sumb4tax)
    a[nexpenses + 3,3] = "VAT ($(my_format(b.moms.p))%)"
    a[nexpenses + 3,4] = my_format(b.tax)
    for (r, deduction) in enumerate(b.deductions)
    a[r + nexpenses + 3,3] = deduction.description
    a[r + nexpenses + 3,4] = my_format(deduction.sum)
    end
    for (r, payment) in enumerate(b.payments)
    a[r + nexpenses + 3 + ndeductions,3] = my_format(payment.date)
    a[r + nexpenses + 3 + ndeductions,4] = my_format(payment.sum)
    end
    a[nexpenses + ndeductions + npayments + 4, 3] = "Balance due"
    a[nexpenses + ndeductions + npayments + 4, 4] = my_format(b.sum)
    return print(GridTable, a)
    end=#

    end # module

    #=b = Budget(Percentile(0))
    x1 = Expense("kaka", 33, 45)
    x2 = Expense("kaki", 3, 45.5)
    x3 = Expense("pipi", 1, 45.5)
    d = Deduction("why not", -100)
    p1 = Payment(now(), -20)
    p2 = Payment(Date(1999,1,22), -50)
    add!(b, x1)
    add!(b, x2)
    add!(b, x3)
    add!(b, d)
    add!(b, p1)
    add!(b, p2)
    budget2array(b)



    for c in ["Item ", "Units ", "Price (SEK) ", "Amount (SEK) "]
    print(aa, c)
    end
    println(aa)
    for expense in b.expenses
    for field in [:description, :units, :price, :sum]
    print(aa, getfield(expense, field))
    end
    println(aa)
    end
    print(STDOUT, aa)

    function write(b::Budget; receipt=false)
    nexpenses = length(b.expenses)
    ndeductions = length(b.deductions)
    a = Any["" for i = 1:nexpenses + ndeductions + 4, j = 1:4]
    a[1,:] = ["Item", "Units", "Price (SEK)", "Amount (SEK)"]
    for j = 1:nexpenses
    a[j + 1,1] = b.expenses[j].description
    a[j + 1,2] = b.expenses[j].units
    a[j + 1,3] = b.expenses[j].price
    \begin{longtabu} to \textwidth { l X c r r }
        \hline
        \blue{Date} & \blue{Description} & \blue{Units} & \blue{Rate} & \blue{Amount} \\
        \hline
        a[j + 1,4] = b.expenses[j].sum
        end
        a[nexpenses + 2,1] = "Fees"
        a[nexpenses + 2,4] = b.sumb4tax
        a[nexpenses + 3,1] = "VAT ($(b.moms)%)"
        a[nexpenses + 3,4] = b.tax
        for j = 1:ndeductions
        a[j + nexpenses + 3,1] = b.deductions[j].description
        a[j + nexpenses + 3,4] = b.deductions[j].sum
        end
        a[end, 1] = "Total"
        a[end, 4] = b.sum
        if receipt
        a[end,1] *= " owed"
        a = cat(1, a, ["Total payed" "" "" b.sum; "Balance" "" "" RoundReal(0)])
        end
        return printMD(a)
        end

        write(x::Expense) = "$(x.description) & $(x.units) & $(x.price) & $(x.sum)\\\\"

        write(x::Deduction) = "$(x.description) & & & $(-x.sum)\\\\"

        function write(b::Budget)
        txt = ["""\\begin{longtable}{l c c r}
            Item & Units & Price (SEK) & Amount (SEK)\\\\
            \\hline"""]
            append!(txt, write.(b.expenses))
            push!(txt, """\\hline
            Fees & & & $(b.sumb4tax)\\\\
            VAT ($(b.moms)\\%) & & & $(b.tax)\\\\""")
            if length(b.deductions) > 0
            append!(txt, write.(b.deductions))
            end
            push!(txt, """\\hline
            \\hline
            \\bf Total & & & \\bf $(b.sum)\\\\
        \\end{longtable}""")
        return join(txt, "\n")
        end

        using StringBuilders
        import StringBuilders:append!
        function append!(sb::StringBuilder, ss::AbstractString...)
        for s in ss
        append!(sb, s)
        end
        end

        o = StringBuilder()
        append!(o, "2")
        String(o)
        append!(o, "3", "4", "5")
        =#
