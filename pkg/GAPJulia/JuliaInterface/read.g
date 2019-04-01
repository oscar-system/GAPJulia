#
# JuliaInterface: Test interface to julia
#
# Reading the implementation part of the package.
#
ReadPackage( "JuliaInterface", "gap/JuliaInterface.gi");
ReadPackage( "JuliaInterface", "gap/BindCFunction.gi" );

if not IsBound( __JULIAINTERNAL_LOADED_FROM_JULIA ) then
    JuliaEvalString( "__GAPINTERNAL_LOADED_FROM_GAP = true" );
    JuliaEvalString( "Base.MainInclude.include(Base.find_package(\"GAP\"))" );
fi;

dirs_julia := DirectoriesPackageLibrary( "JuliaInterface", "julia" );

JuliaIncludeFile( Filename( dirs_julia, "gaptypes.jl" ) );

JuliaEvalString( Concatenation( "__JULIAGAPMODULE.include( \"", Filename( dirs_julia, "libgap.jl" ), "\")" ) );

_JULIAINTERFACE_INTERNAL_INIT();

## The GAP module is also bound to the variable __JULIAGAPMODULE,
## to prevent name clashes when accessing it before it is completely initialized.
Julia!.storage.GAP := _WrapJuliaModule( "GAP", _JuliaGetGlobalVariable( "__JULIAGAPMODULE" ) );

ReadPackage( "JuliaInterface", "gap/adapter.gi");
ReadPackage( "JuliaInterface", "gap/calls.gi");
ReadPackage( "JuliaInterface", "gap/convert.gi");
ReadPackage( "JuliaInterface", "gap/utils.gi");
ReadPackage( "JuliaInterface", "gap/JuliaTranspiler.gi");
