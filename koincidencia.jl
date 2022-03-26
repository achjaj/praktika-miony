using Dates
using DataFrames
using Plots
using Latexify
using StatsBase

function toPeriod(timeStr::String, delim = ":")
    types = [Hour, Minute, Second, Millisecond, Microsecond, Nanosecond]

    timeStr = replace(timeStr, '.' => delim)
    arr = map(s -> parse(Int64, s), split(timeStr, delim))

    sum(t(v) for (t, v) in zip(types, arr))
end

toNanos(period::Dates.CompoundPeriod) = sum(Nanosecond.(period.periods))

hasDay(period::Dates.CompoundPeriod) = Day in typeof.(period.periods)

function parseFile(path::String)
    start = toPeriod(readline(path))

    times = Vector{Time}()
    for line in eachline(path)
        period = canonicalize(toPeriod(line) - start)

        if (!hasDay(period)) # truncate to 24h
            push!(times, Time(0) + period)
        end
    end

    times
end

function mkHist(t::Vector{Time}, l::String, s::Time, m::Float64)
    hours = hour.(t)
    counts = [count(==(i), hours) for i in unique(hours)]

    bar(1:length(counts), counts, legend = false, xlabel = "Hour", ylabel = "Count", grid = false, title = "$l\n$(Dates.format(s, dateformat"H:MM"))", yerror = sqrt.(counts))
    hline!([m])
end

function toTex(data::DataFrame)
    table = data[:, [1, 5, 7]]

    write("table.tex", latexify(table, env=:table, latex=false, booktabs=true))
end

function exportHist(data::DataFrame)
    for (h, l) in zip(data.hists, data.City)
        savefig(h, l * ".png")
    end
end

function countTimes(times::Vector{Time})
    minutes = [round(t.instant, Minute).value for t in times]
    max = maximum(minutes)
    edges = [i+1 for i in 0:max]
    fit(Histogram, minutes, edges)


    #=bins = [i:Nanosecond(1):i+Minute(1) for i in Time(0):Minute(1):max]
    counts = fill(0, length(bins))
    for t in times
        for (i, bin) in enumerate(bins)
            if t in bin
                counts[i] += 1
                continue
            end
        end
    end

    bins#[Minute(hour(b[end])) + Minute(b[end]) for b in bins], counts=#
end

approxIn(value::Nanosecond, arr::Vector{Nanosecond}, atol) = sum(isapprox(value.value, arrV.value; atol = atol) for arrV in arr) > 0
pad(arr::Vector, len::Int) = [arr; fill("-", len - length(arr))]

files = ["PRG_coincidence-2022_03_10.txt", "CPH-Coincidence-10-3-22.txt", "13-07-33_2022-03-10.txt"]

prg, cph, mln = 1, 2, 3

data = DataFrame(City = ["Prague", "Copenhagen", "Milano"],
                 start = [Time(0) + toPeriod(readline(file)) for file in files],
                 nanos = [toNanos.(toPeriod.(readlines(file))) for file in files],
                 normTimes = [parseFile(file) for file in files])

data[!, :nanoSpan] = [t[end].instant for t in data.normTimes]
data[!, "Time span"] = string.(canonicalize.(round.(data.nanoSpan, Minute)))

data[!, :CPN] = length.(data.normTimes) ./ (s.value for s in data.nanoSpan)
data[!, "Coincidence per hour"] = round.(data.CPN .* Nanosecond(Hour(1)).value, sigdigits=5)
data[!, :hists] = [mkHist(t, l, s, m) for (t, l, s, m) in zip(data.normTimes, data.City, data.start, data[:, "Coincidence per hour"])]

toTex(data)
exportHist(data)

#= look for coincidences between universities
tol = Nanosecond(Microsecond(1)).value # resolution
# firtsly we need to find common time window
data[!, :hours] = [map(h -> h.value, round.(nano, Hour)) for nano in data.nanos]
common = intersect(data.hours...)
windowStart, windowEnd = common[1], common[end]

# filter times to time window
data[!, :fNanos] = [filter(n -> windowStart <= round(n, Hour).value <= windowEnd, nans) for nans in data.nanos]

prgCph = filter(prgt -> approxIn(prgt, data.nanos[cph], tol), data.nanos[prg])
prgMln = filter(prgt -> approxIn(prgt, data.nanos[mln], tol), data.nanos[prg])
cphMln = filter(cpht -> approxIn(cpht, data.nanos[mln], tol), data.nanos[cph])

prgCphMln = filter(prgcpht -> approxIn(prgcpht, data.nanos[mln], tol), prgCph)

startDate = DateTime(2022, 3, 10)
form = dateformat"HH:MM:SS.s:% e"
datedPrgCph = [replace(Dates.format(startDate + t, form), "%" => canonicalize(t).periods[end-1].value) for t in prgCph]
datedPrgMln = [replace(Dates.format(startDate + t, form), "%" => canonicalize(t).periods[end-1].value) for t in prgMln]
datedCphMln = [replace(Dates.format(startDate + t, form), "%" => canonicalize(t).periods[end-1].value) for t in cphMln]

table = DataFrame()
table[!, "Prague - Copenhagen"] = pad(datedPrgCph, 5)
table[!, "Prague - Milano"] = pad(datedPrgMln, 5)
table[!, "Copenhagen - Milano"] = pad(datedCphMln, 5)

write("table2.tex", latexify(table, env=:table, latex=false, booktabs=true))=#