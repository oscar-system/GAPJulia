@testset "packages" begin

    @test GAP.Packages.load("PackageManager")
    @test ! GAP.Packages.load("no such package")
    @test ! GAP.Packages.load("no such package", install = true)

    tmproot = mktempdir()
    pkgdir = joinpath(tmproot, "pkg")
    mkpath(pkgdir)
    GAP.Globals.ExtendRootDirectories(GapObj([tmproot * "/"]; recursive=true))
    @test GAP.Packages.install("io", interactive = false, pkgdir = pkgdir)
    @test GAP.Packages.remove("io", interactive = false, pkgdir = pkgdir)

end

@testset "LoadPackageAndExposeGlobals" begin

    LoadPackageAndExposeGlobals("GAPDoc", "test1")
    @test isdefined(test1, :SymmetricGroup) == false

    LoadPackageAndExposeGlobals("GAPDoc", "test2", all_globals = true)
    @test isdefined(test2, :SymmetricGroup) == true

    LoadPackageAndExposeGlobals("GAPDoc", test3, all_globals = true)
    @test test3.SymmetricGroup == 5

end
