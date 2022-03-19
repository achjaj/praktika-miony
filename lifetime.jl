using DelimitedFiles
using Dates
using Plots
using LsqFit

function process(file::String)
    times = readdlm(file, ';')[:, end-1]
    bins = [i:i+200 for i in 0:200:maximum(times)]
    x = [range[end] * 1e-3 for range in bins]
    counts = fill(0, length(bins))

    for t in times
        for (i, bin) in enumerate(bins)
            if t in bin
                counts[i] += 1
                continue
            end
        end
    end

    @. model(x, p) = p[1] + p[2]*exp(-x/p[3])
    fit = curve_fit(model, x, counts, [0.1, 0.01, 0.01])

    plt = scatter(x, counts, label = "", grid = false, xlabel = "Time [μs]", ylabel = "Count")
    plot!(plt, x, a -> model(a, fit.param), label = "Fit")

    fit, plt
end

files = ["CPH-Lifetime-11-03-22.txt"; filter(d -> occursin("test", d), readdir("."))]

results = process.(files)