using DelimitedFiles
using Dates
using Plots
using LsqFit
using Formatting
using StatsBase

function degree(num)
    fe = FormatExpr("{:.0e}")
    10.0^(parse(Int, split(format(fe, num), "e")[2])+1)
end

function countTimes(times::Vector; binsize = 250)
    max = maximum(times)
   # edges = [i+binsize for i in 0:binsize:max]
    fit(Histogram, times, nbins = round(Int, max/binsize))
end

function process(times::Vector{Int}, title)
    hist = countTimes(times)

    @. model(x, p) = p[1] + p[2]*exp(-x/p[3])
    fit = curve_fit(model, hist.edges[1][2:end], hist.weights, [0.1, 0.01, 1000])

    err = round(standard_errors(fit)[end], sigdigits=1)
    m = degree(err)
    τ = round(fit.param[end]/m, digits=1)*m

    if m > 1
        τ = Int(round(Int, τ))
        err = Int(err)
    end

    plt = scatter(hist.edges[1][2:end], hist.weights, label = "", grid = false, xlabel = "Time [ns]", ylabel = "Count", title = title)
    plot!(plt, hist.edges[1][2:end], a -> model(a, fit.param), label = "Fit: τ = ($τ ± $err) ns")
    plot!(plt, hist.edges[1][2:end], a -> model(a, [fit.param[1], fit.param[2], 2196.981]), label = "PDG 2020: τ = (2196.981 ± 0.0022) ns")

    fit, plt
end

prgFiles = filter(d -> occursin("test", d), readdir("."))
prgData = [filter(x -> x >= 2000, Int.(readdlm(f, ';')[:, end-1])) for f in prgFiles]

data = vcat([Int.(readdlm("CPH-Lifetime-11-03-22.txt", ';')[:, end-1])], prgData)
titles = ["Copenhagen 11. 3."; ["Prague $d. 3." for d in [4, 8, 11, 14]]]

results = process.(data, titles)
savefig.(getindex.(results, 2), "lifetime/" .* titles .* ".svg")
