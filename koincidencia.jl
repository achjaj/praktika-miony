using Dates
using DataFrames
using Plots
using Latexify

function toPeriod(timeStr::String, delim = ":")
    types = [Hour, Minute, Second, Millisecond, Microsecond, Nanosecond]

    timeStr = replace(timeStr, '.' => delim)
    arr = map(s -> parse(Int64, s), split(timeStr, delim))

    sum(t(v) for (t, v) in zip(types, arr))
end

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

files = ["PRG_coincidence-2022_03_10.txt", "CPH-Coincidence-10-3-22.txt", "13-07-33_2022-03-10.txt"]

prg, cph, mln = 1, 2, 3

data = DataFrame(City = ["Prague", "Copenhagen", "Milano"],
                 start = [Time(0) + toPeriod(readline(file)) for file in files],
                 times = [parseFile(file) for file in files])

data[!, :nanos] = [t[end].instant for t in data.times]
data[!, "Time span"] = string.(canonicalize.(round.(data.nanos, Minute)))

data[!, :CPN] = length.(data.times) ./ (s.value for s in data.nanos)
data[!, "Coincidence per hour"] = round.(data.CPN .* Nanosecond(Hour(1)).value, sigdigits=5)
data[!, :hists] = [mkHist(t, l, s, m) for (t, l, s, m) in zip(data.times, data.City, data.start, data[:, "Coincidence per hour"])]