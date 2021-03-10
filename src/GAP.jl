@doc Markdown.doc"""
  GAP.jl is the Julia interface to the GAP-System.

  For more information about GAP see https://www.gap-system.org/
""" module GAP

using GAP_jll

include("setup.jl")

# always force regeneration of GAPROOT when precompiling
const GAPROOT = Setup.regenerate_gaproot()

import Base: length, finalize
import Libdl
import Markdown
import Random

include("types.jl")

const sysinfo = Setup.read_sysinfo_gap(GAPROOT)
const GAP_VERSION = VersionNumber(sysinfo["GAP_VERSION"])

function reset_GAP_ERROR_OUTPUT()
    # Note: strictly speaking we should close the stream here; but since it is
    # a string stream, this does nothing. So we don't do it, which saves us
    # some hassle when calling reset_GAP_ERROR_OUTPUT from `initialize`
    #Globals.CloseStream(Globals.ERROR_OUTPUT)
    evalstr("_JULIAINTERFACE_ERROR_OUTPUT:= \"\";")
    Globals.MakeReadWriteGlobal(julia_to_gap("ERROR_OUTPUT"))
    evalstr("ERROR_OUTPUT:= OutputTextString( _JULIAINTERFACE_ERROR_OUTPUT, true );")
    evalstr("SetPrintFormattingStatus( ERROR_OUTPUT, false )")
    Globals.MakeReadOnlyGlobal(julia_to_gap("ERROR_OUTPUT"))
end

disable_error_handler = false

function error_handler()
    global disable_error_handler
    if disable_error_handler
        return
    end
    str = String(Globals._JULIAINTERFACE_ERROR_OUTPUT)
    reset_GAP_ERROR_OUTPUT()
    error("Error thrown by GAP: ", str)
end

# The following hack is needed only in Julia 1.3, not in later versions.
error_handlerwrap() = Base.invokelatest(error_handler)

# This will be filled out by __init__(), as it must be done at runtime
JuliaInterface_path = ""

# This will be filled out by __init__()
JuliaInterface_handle = C_NULL

# This must be `const` so that we can use it with `ccall()`
const JuliaInterface = "JuliaInterface.so"

function initialize(argv::Array{String,1})
    handle_signals = isdefined(Main, :__GAP_ARGS__)  # a bit of a hack...
    error_handler_func = handle_signals ? C_NULL : @cfunction(error_handlerwrap, Cvoid, ())

    # Tell GAP to read a file during startup (after its `lib/system.g`),
    # such that `JuliaInterface` is added to the autoloaded GAP packages,
    # and such that (in GAP standalone mode) files read from the GAP command
    # line are not read before the Julia module `GAP` is available;
    # these files will be read via a function call in `gap.sh`
    # (which is created by `setup.jl`).
    append!(argv, ["--systemfile", abspath(@__DIR__, "..", "lib", "systemfile.g")])

    ## At this point, the GAP module has not been completely initialized, and
    ## hence is not yet available under the global binding "GAP"; but
    ## JuliaInterface needs to access it. To make that possible, we assign
    ## this module to the name __JULIAGAPMODULE.
    ## TODO: find a way to avoid using such a global variable
    gap_module = @__MODULE__
    Base.MainInclude.eval(:(__JULIAGAPMODULE = $gap_module))

    if ! handle_signals
        # Tell GAP to show some traceback on errors.
        append!(argv, ["--alwaystrace"])
    end

    # instruct GAP to not load init.g at the end of GAP_Initialize
    # TODO: turn this into a proper libgap API
    unsafe_store!(cglobal((:SyLoadSystemInitFile, libgap), Int64), 0)

    ccall(
        (:GAP_Initialize, libgap),
        Cvoid,
        (Int32, Ptr{Ptr{UInt8}}, Ptr{Cvoid}, Ptr{Cvoid}, Cuint),
        length(argv),
        argv,
        C_NULL,
        error_handler_func,
        handle_signals,
    )
    
    # TODO: store a pointer to this module in a GAP variable
    #... 

    # now load init.g
    @debug "about to read init.g"
    if (ccall((:READ_GAP_ROOT, libgap), Int64, (Ptr{Cchar},), "lib/init.g") == 0)
        error("failed to read lib/init.g")
    end
    @debug "finished reading init.g"

    # detect if GAP quit early (e.g due `-h` or `-c` command line arguments)
    # TODO: restrict this to "standalone" mode?
    # HACK: GAP resp. libgap currently offers no good way to detect this
    # (perhaps this could be a return value for GAP_Initialize?),
    # so instead we check for the presence of the global variable
    # __JULIAINTERNAL_LOADED_FROM_JULIA which we ensure is declared near the
    # end of init.g, via a `-c` command line argument to GAP;
    # this argument is set in `lib/systemfile.g`.
    val = _ValueGlobalVariable("__JULIAINTERNAL_LOADED_FROM_JULIA")

    if val == C_NULL
        # Ask GAP to quit. Note that this invokes `jl_atexit_hook` so it
        # should be fine. It might be "nicer" to call Julia's `exit` function
        # here; but unfortunately we can't access GAP's exit code, which is
        # stored in `SystemErrorCode`, a statically linked (and hence
        # invisible to us) GAP C kernel variable. Hence we instead call
        # FORCE_QUIT_GAP with no arguments, which just calls the `exit`
        # function of the  C standard library with the appropriate exit code.
        # But as mentioned, just before that, it runs `jl_atexit_hook`.
        FORCE_QUIT_GAP = _ValueGlobalVariable("FORCE_QUIT_GAP")
        ccall(
            (:GAP_CallFuncArray, libgap),
            Ptr{Cvoid},
            (Any, Culonglong, Ptr{Cvoid}),
            FORCE_QUIT_GAP,
            0,
            C_NULL,
        )
        # we shouldn't get here, but just in case....
        error("FORCE_QUIT_GAP failed")
    end

    # verify our TNUMs are still correct
    @assert T_INT == ValueGlobalVariable(:T_INT)
    @assert T_INTPOS == ValueGlobalVariable(:T_INTPOS)
    @assert T_INTNEG == ValueGlobalVariable(:T_INTNEG)
    @assert T_RAT == ValueGlobalVariable(:T_RAT)
    @assert T_CYC == ValueGlobalVariable(:T_CYC)
    @assert T_FFE == ValueGlobalVariable(:T_FFE)
    @assert T_MACFLOAT == ValueGlobalVariable(:T_MACFLOAT)
    @assert T_PERM2 == ValueGlobalVariable(:T_PERM2)
    @assert T_PERM4 == ValueGlobalVariable(:T_PERM4)
    @assert T_TRANS2 == ValueGlobalVariable(:T_TRANS2)
    @assert T_TRANS4 == ValueGlobalVariable(:T_TRANS4)
    @assert T_PPERM2 == ValueGlobalVariable(:T_PPERM2)
    @assert T_PPERM4 == ValueGlobalVariable(:T_PPERM4)
    @assert T_BOOL == ValueGlobalVariable(:T_BOOL)
    @assert T_CHAR == ValueGlobalVariable(:T_CHAR)
    @assert T_FUNCTION == ValueGlobalVariable(:T_FUNCTION)
    @assert T_BODY == ValueGlobalVariable(:T_BODY)
    @assert T_FLAGS == ValueGlobalVariable(:T_FLAGS)
    @assert T_LVARS == ValueGlobalVariable(:T_LVARS)
    @assert T_HVARS == ValueGlobalVariable(:T_HVARS)
    @assert FIRST_EXTERNAL_TNUM == ValueGlobalVariable(:FIRST_EXTERNAL_TNUM)

    # check that JuliaInterface has been loaded
    # (it binds the GAP variable `Julia`)
    if _ValueGlobalVariable("Julia") == C_NULL
        error("JuliaInterface could not be loaded")
    end

    # If we are in "stand-alone mode", stop here
    if handle_signals
        ccall((:SyInstallAnswerIntr, libgap), Cvoid, ())
        return
    end

    # open JuliaInterface.so, too
    #global JuliaInterface_path = CSTR_STRING(EvalString("""Filename(DirectoriesPackagePrograms("JuliaInterface"), "JuliaInterface.so");"""))
    global JuliaInterface_path = normpath(joinpath(@__DIR__, "..", "pkg", "JuliaInterface", "bin", sysinfo["GAParch"], JuliaInterface))
    global JuliaInterface_handle = Libdl.dlopen(JuliaInterface_path)

    # Redirect error messages, in order not to print them to the screen.
    Base.invokelatest(reset_GAP_ERROR_OUTPUT)
end

function finalize()
    ccall((:GAP_finalize, libgap), Cvoid, ())
end

# Show a more helpful error message for users on Windows.
windows_error() = error("""

    This package unfortunately does not run natively under Windows.
    Please install Julia using Windows subsystem for Linux and try again.
    See also https://oscar.computeralgebra.de/install/.
    """)

# error message at precompile time
if Sys.iswindows()
  windows_error()
end

function __init__()
    # error message at runtime
    if Sys.iswindows()
        windows_error()
    end

    # regenerate GAPROOT if it was removed
    if !isdir(GAPROOT) || isempty(readdir(GAPROOT))
        Setup.setup_mutable_gaproot(GAPROOT)
    end

    gaproots = sysinfo["GAPROOTS"]
    cmdline_options = ["", "-l", gaproots]
    if isdefined(Main, :__GAP_ARGS__)
        append!(cmdline_options, Main.__GAP_ARGS__)
    else
        append!(cmdline_options, ["--nointeract"])
    end

    if haskey(ENV, "GAP_SHOW_BANNER")
        show_banner = ENV["GAP_SHOW_BANNER"] == "true"
    else
        show_banner =
            isinteractive() && !any(x -> x.name in ["Oscar"], keys(Base.package_locks))
    end

    if !show_banner
        # Do not show the main GAP banner by default.
        push!(cmdline_options, "-b")
    end


    # The following withenv is needed to get readline input to work right; see also
    # https://github.com/JuliaPackaging/Yggdrasil/issues/455 and
    # https://github.com/oscar-system/GAP.jl/issues/415
    withenv("TERMINFO_DIRS" => joinpath(GAP_jll.Readline_jll.Ncurses_jll.find_artifact_dir(), "share", "terminfo")) do
        initialize(cmdline_options)
    end

    if !show_banner
        # Leave it to GAP's `LoadPackage` whether package banners are shown.
        # Note that a second argument `false` of this function suppresses the
        # package banner,
        # but no package banners can be shown if the `-b` option is `true`.
        gap_module = @__MODULE__
        Base.MainInclude.eval(
            :(
                begin
                    record = $gap_module.Globals.GAPInfo
                    record.CommandLineOptions =
                        $gap_module.Globals.ShallowCopy(record.CommandLineOptions)
                    record.CommandLineOptions.b = false
                    $gap_module.Globals.MakeImmutable(record.CommandLineOptions)
                end
            ),
        )
    end
end

"""
    GAP.randseed!([seed::Integer])

Reseed GAP's global RNG with `seed`.

The given `seed` must be a non-negative integer.
When `seed` is not specified, a random seed is generated from Julia's global RNG.

For a fixed seed, the stream of generated numbers is allowed to change between
different versions of GAP.
"""
function randseed!(seed::Union{Integer,Nothing}=nothing)
    seed = something(seed, rand(UInt128))
    Globals.Reset(Globals.GlobalMersenneTwister, seed)
    # when GlobalRandomSource is reset, the seed is taken modulo 2^28, so we just
    # pass an already reduced seed here
    Globals.Reset(Globals.GlobalRandomSource, seed % Int % 2^28)
    nothing
end

include("lowlevel.jl")
include("ccalls.jl")
include("adapter.jl")
include("macros.jl")
include("gap_to_julia.jl")
include("constructors.jl")
include("convert.jl")
include("julia_to_gap.jl")
include("utils.jl")
include("help.jl")
include("packages.jl")
include("prompt.jl")
include("obsolete.jl")
include("doctestfilters.jl")

end
