#!/usr/bin/env bash

set -e

main_dir=${PWD}

# Download and install Julia
wget https://julialangnightlies-s3.julialang.org/bin/linux/x64/julia-latest-linux64.tar.gz
mkdir julia
tar xf julia-latest-linux64.tar.gz -C julia --strip-components 1

if [[ $DONT_BUILD_JULIA_PKGS != yes ]] ; then
    ${main_dir}/julia/bin/julia <<UNTILEND
using Pkg
Pkg.add("AbstractAlgebra")
Pkg.add("Nemo")
Pkg.add(PackageSpec(url="https://github.com/thofma/Hecke.jl"))
Pkg.add(PackageSpec(url="https://github.com/oscar-system/Singular.jl"))
Pkg.add(PackageSpec(url="https://github.com/ederc/GB.jl", rev="master" ))
UNTILEND
fi

# Download and install GAP
git clone --depth=1 https://github.com/gap-system/gap
cd gap
./autogen.sh
./configure --with-gc=julia --with-julia=${main_dir}/julia/
make -j4
make bootstrap-pkg-full
if [[ $DONT_BUILD_GAP_PKGS != yes ]] ; then
    cd pkg
    ${main_dir}/gap/bin/BuildPackages.sh
fi

# Compile main GAP manuals
cd $main_dir/gap
make doc

# Download and install GAPJulia
cd pkg
if [[ $DONT_FETCH_GAP_JULIA_PKG = yes ]] ; then exit 0; fi
git clone https://github.com/oscar-system/GAPJulia
cd GAPJulia
./configure $main_dir/gap/
make

if [[ $DONT_BUILD_JULIA_PKGS != yes ]] ; then
    # Download and install Polymake
    cd $main_dir
    git clone https://github.com/polymake/polymake.git
    mv polymake polymakegit
    cd polymakegit
    git checkout Snapshots
    ./configure --prefix=${main_dir}/polymake
    ninja -C build/Opt
    ninja -C build/Opt install

    # now Polymake.jl
    cd ${main_dir}
    export POLYMAKE_CONFIG=${main_dir}/polymake/bin/polymake-config
    julia/bin/julia <<UNTILEND
using Pkg
Pkg.add(PackageSpec(url="https://github.com/oscar-system/Polymake.jl"))
UNTILEND
fi


