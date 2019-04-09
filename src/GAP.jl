module GAP

include(abspath(joinpath(@__DIR__, "..", "deps", "deps.jl")))
include( "repl.jl" )

"""
    FFE

> Wraps a pointer to a GAP FFE immediate object
> This type is defined in the JuliaInterface C code.
"""

primitive type FFE 64 end

export FFE

import Base: length, convert, finalize

import Libdl

sysinfo = missing

read_sysinfo_gap = function(dir::String)
    d = missing
    open(dir * "/sysinfo.gap") do file
        d = Dict{String,String}()
        for ln in eachline(file)
            if length(ln) == 0 || ln[1] == '#'
                continue
            end
            s = split(ln, "=")
            if length(s) != 2 
                continue
            end
            d[s[1]] = strip(s[2], [ '"' ])
        end
    end
    return d
end

function error_handler()
    error("Error thrown by GAP")
end


const pkgdir = realpath(dirname(@__FILE__))

function initialize( argv::Array{String,1}, env::Array{String,1}, error_handler_func::Ptr{Nothing} )
    gap_library = Libdl.dlopen("libgap", Libdl.RTLD_GLOBAL)
    ccall( Libdl.dlsym(gap_library, :GAP_Initialize)
           , Cvoid
           , (Int32, Ptr{Ptr{UInt8}},Ptr{Cvoid},Ptr{Cvoid},Cuint)
           , length(argv)
           , argv
           , C_NULL
           , error_handler_func
           , Cuint(0) )
    ccall( Libdl.dlsym(gap_library, :GAP_EvalString)
           , Ptr{Cvoid}
           , (Ptr{UInt8},)
           , "BindGlobal(\"__JULIAINTERNAL_LOADED_FROM_JULIA\", true );" )
    ccall( Libdl.dlsym(gap_library, :GAP_EvalString)
           , Ptr{Cvoid}
           , (Ptr{UInt8},)
           , "_JULIAINTERNAL_JULIAINTERFACE_LOADED := LoadPackage(\"JuliaInterface\");" )
    loadpackage_return = ccall( Libdl.dlsym(gap_library, :GAP_EvalString)
           , Ptr{Cvoid}
           , (Ptr{UInt8},)
           , "_JULIAINTERNAL_JULIAINTERFACE_LOADED;" )
    if loadpackage_return == Libdl.dlsym(gap_library, :GAP_Fail )
        throw(ErrorException( "JuliaInterface could not be loaded" ))
    end
end

function finalize( )
    ccall( (:GAP_finalize, "libgap")
           , Cvoid
           , () )
end

gap_is_initialized = false

run_it = function(gapdir::String, error_handler_func::Ptr{Nothing})
    global sysinfo, gap_is_initialized
    if gap_is_initialized
        error("GAP already initialized")
    end
    sysinfo = read_sysinfo_gap(gapdir)
    println("Adding path ", gapdir * "/.libs", " to DL_LOAD_PATH")
    push!( Libdl.DL_LOAD_PATH, gapdir * "/.libs" )
    initialize( [ ""
                       , "-l", sysinfo["GAP_LIB_DIR"]
                       , "-T", "-r", "-A", "--nointeract"
                       , "-l", "$(EXTRA_GAPROOT);"
#                      , "-m", "512m" ], [""] )
                       , "-m", "1000m" ], [""], error_handler_func )
    gap_is_initialized = true
end

function __init__()
    error_handler_func = @cfunction(error_handler, Cvoid, ())

    ## We temporarily assign this module to the name __JULIAGAPMODULE
    ## to not bind GAP in the Main namespace, as this causes a warning when
    ## the module is loaded.
    gap_module = @__MODULE__
    Base.MainInclude.eval(:(__JULIAGAPMODULE = $gap_module))
    if ! isdefined(Main, :__GAPINTERNAL_LOADED_FROM_GAP) || Main.__GAPINTERNAL_LOADED_FROM_GAP != true
        run_it(GAPROOT, error_handler_func)
    end
    if isdefined(Base, :active_repl)
        run_gap_repl()
    end
end

end
