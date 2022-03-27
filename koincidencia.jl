using Dates
using DataFrames
using Plots
using Latexify
using StatsBase

gr()
default(label = "")

function toNanos(timeStr::String, delim = ":")
    types = [Hour, Minute, Second, Millisecond, Microsecond, Nanosecond]

    timeStr = replace(timeStr, '.' => delim)
    arr = map(s -> parse(Int64, s), split(timeStr, delim))

    sum(Nanosecond(t(v)) for (t, v) in zip(types, arr))
end

hasDay(period::Dates.CompoundPeriod) = Day in typeof.(period.periods)

function parseFile(file::String)
    start = toNanos(readline(file))
    day = Nanosecond(Day(1))

    #nanos = Vector{Nanosecond}()
    #=for line in eachline(path)
        period = canonicalize(toNanos(line) - start)

        if (!hasDay(period)) # truncate to 24h
            push!(nanos, period)
        end
    end=#

    filter(nano -> (nano - start) < day, toNanos.(eachline(file)))
end

function mkHist(nanos::Vector{Nanosecond}, city::String, start::Nanosecond, mean::Float64)
    mult = Nanosecond.(Hour(1)).value
    edges = collect(0:24) .* mult

    hist = fit(Histogram, [n.value for n in nanos .- start], edges, closed=:right)

    plotx = edges[2:end] ./ mult
    plt = plot(plotx, hist.weights, markershape=:rect, linestyle=:dot, xticks = plotx, xlabel = "Hour", ylabel = "Count", title = city, legend=:outertopright)

    yt = yticks(plt[1])
    yticks!(([yt[1]; mean], [yt[2]; string(Int(mean))]))

    xt = xticks(plt[1])
    map(i -> xt[2][i] = "", 2:2:length(plotx))
    xticks!(xt)

    hline!([mean], linestyle=:dash, label = "Mean c/h")
end 

function toTex(data::DataFrame)
    table = data[:, [1, 5, 7]]

    write("table.tex", latexify(table, env=:table, latex=false, booktabs=true))
end

function exportHist(data::DataFrame)
    for (h, l) in zip(data.hists, data.City)
        savefig(h, l * ".svg")
    end
end

approxIn(value::Nanosecond, arr::Vector{Nanosecond}, atol) = sum(isapprox(value.value, arrV.value; atol = atol) for arrV in arr) > 0
pad(arr::Vector, len::Int) = [arr; fill("-", len - length(arr))]

files = ["PRG_coincidence-2022_03_10.txt", "CPH-Coincidence-10-3-22.txt", "13-07-33_2022-03-10.txt"]

prg, cph, mln = 1, 2, 3

data = DataFrame(City = ["Prague", "Copenhagen", "Milano"],
                 start = [toNanos(readline(file)) for file in files],
                 nanos = parseFile.(files))

data[!, :nanoSpan] = [n[end] - s for (n, s) in zip(data.nanos, data.start)]
data[!, "Time span"] = string.(canonicalize.(round.(data.nanoSpan, Minute)))

data[!, :CPN] = length.(data.nanos) ./ (s.value for s in data.nanoSpan)
data[!, "Coincidence per hour"] = round.(data.CPN .* Nanosecond(Hour(1)).value, sigdigits=5)
data[!, :hists] = [mkHist(t, l, s, m) for (t, l, s, m) in zip(data.nanos, data.City, data.start, data[:, "Coincidence per hour"])]

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