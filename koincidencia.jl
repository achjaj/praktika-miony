using Dates
using DataFrames
using Plots
using DelimitedFiles

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

function toCSV(data::DataFrame)
    table = data[:, [1, 3:(end-1)...]]
    labels = ["City", "Time span", "Coincidence per nanosecond", "Coincidence per hour"]
    table.span = canonicalize.(round.(table.span, Minute))
    table.CPN = round.(table.CPN, sigdigits=3)
    table[:, 4] = round.(table[:, 4], sigdigits=4)

    writedlm("table", vcat(reshape(labels, 1, 4), Matrix(table)))
end

function exportHist(data::DataFrame)
    for (h, l) in zip(data.Histograms, data.city)
        savefig(h, l * ".png")
    end
end

files = ["PRG_coincidence-2022_03_10.txt", "CPH-Coincidence-10-3-22.txt", "13-07-33_2022-03-10.txt"]

prg, cph, mln = 1, 2, 3
data = DataFrame(city = ["Prague", "Copenhagen", "Milano"], times = [parseFile(file) for file in files])
data[!, :span] = [t[end] - t[1] for t in data.times]

data[!, :CPN] = length.(data.times) ./ (s.value for s in data.span)
data[!, "Coincidence per hour"] = data.CPN .* Nanosecond(Hour(1)).value
data[!, "Histograms"] = [histogram(hour.(t), legend = false, xlabel = "Hour", ylabel = "Count", title = l) for (t, l) in zip(data.times, data.city)]

# ! SLOW !
#prgCph = filter(t -> t in data.times[prg], data.times[cph])
#prgMln = filter(t -> t in data.times[prg], data.times[mln])
#cphMln = filter(t -> t in data.times[cph], data.times[mln])
# no coincidences