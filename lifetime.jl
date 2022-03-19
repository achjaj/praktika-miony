using DelimitedFiles
using Dates
using Plots

mcount(x) = [count(==(i), x) for i in unique(x)]

nanos = Nanosecond.(readdlm("CPH-Lifetime-11-03-22.txt", ';')[:, end-1])
micros = round.(nanos, Nanosecond(250))
counts = mcount(micros)
scatter(1:length(counts), counts)