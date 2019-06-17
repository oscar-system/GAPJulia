# Builds GAP with julia GC, compiles/links GAPJulia against it,
# and exposes the right paths to julia/GAP

import Pkg

extra_gap_root = abspath(joinpath(@__DIR__, ".."))
gap_root = abspath(joinpath(extra_gap_root, "gap"))
install_gap = true

if haskey(ENV, "GAPROOT")
    gap_root = ENV["GAPROOT"]
    install_gap = false
end

println("gap_root = ", gap_root)
println("extra_gap_root = ", extra_gap_root)
println("install_gap = ", install_gap)

## Find julia binary
julia_binary = get(ENV, "JULIA_BINARY", Sys.BINDIR)

## Install GAP
if install_gap
    println("Installing GAP ...")
    cd(extra_gap_root)
    ## TODO: We currently use the GAP master branch.
    ##       Once all issues of using GAP with the julia
    ##       GC are resolved, we switch to a stable version.
    run(`git clone https://github.com/gap-system/gap`)
    cd("gap")
    run(`./autogen.sh`)
    run(`./configure --with-gc=julia --with-julia=$(julia_binary)`)
    run(`make -j$(Sys.CPU_THREADS)`)
    gap_install_packages =  get(ENV, "GAP_INSTALL_PACKAGES", "yes")
    if gap_install_packages == "yes"
        run(`make bootstrap-pkg-full`)
        cd("pkg")
        run(`../bin/BuildPackages.sh`)
    elseif gap_install_packages == "minimal"
        run(`make bootstrap-pkg-minimal`)
    elseif gap_install_packages == "debug"
        run(`make bootstrap-pkg-minimal`)
        cd("pkg")
        run(`git clone https://github.com/gap-packages/io`)
        run(`git clone https://github.com/gap-packages/profiling`)
        run(`../bin/BuildPackages.sh --with-gaproot=$(gap_root) io profiling`)
    end
end

gap_executable = abspath(joinpath(gap_root, "gap"))

##
## Compile JuliaInterface/Experimental
##
println("Compiling JuliaInterface and JuliaExperimental ...")
cd(abspath(joinpath(@__DIR__, "..", "pkg", "GAPJulia" )))
run(`./configure $gap_root`)
run(`make`)

##
## Write deps.jl file containing the necessary paths
##
println("Generating deps.jl ...")

deps_string = """
GAPROOT = "$gap_root"
GAP_EXECUTABLE = "$gap_executable"
EXTRA_GAPROOT = "$extra_gap_root"

"""

path = abspath(joinpath(@__DIR__, "deps.jl"))
println(path)
open(path, "w") do outputfile
    print(outputfile,deps_string)
end

##
## Create custom gap.sh
##
println("Generating gap.sh ...")

gap_sh_string = """
#!/bin/sh

exec "$(gap_root)/gap" -l "$(extra_gap_root);$(gap_root)" "\$@"
"""
 
gap_sh_path = abspath(joinpath(extra_gap_root, "gap.sh"))
open(gap_sh_path, "w") do outputfile
    print(outputfile, gap_sh_string)
end

cd(extra_gap_root)
run(`chmod +x gap.sh`)
julia_gap_sh_link = abspath(joinpath(Pkg.depots1(), "gap"))
run(`ln -snf $gap_sh_path $julia_gap_sh_link`)
