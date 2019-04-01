LoadPackage( "JuliaInterface" );

bubble_sort := function( list, len )
    local i, j, tmp;
    
    for i in [ 1 .. len ] do
        for j in [ 1 .. len - 1 ] do
            if list[ j ] > list[ j + 1 ] then
                tmp := list[ j + 1 ];
                list[ j + 1 ] := list[ j ];
                list[ j ] := tmp;
            fi;
        od;
    od;
    return list;
end;


bubble_sort_jl := TRANSPILE_FUNC( bubble_sort );
bubble_sort_jl := Julia.Base.eval( bubble_sort_jl );

length := 10000;

xx := List( [ 1 .. length ], i -> RandomList( [ 1 .. length ] ) );;
xx_jl := GAPToJulia( JuliaEvalString( "Vector{Int64}"), xx );;

bubble_sort( xx, length );;
time;

bubble_sort_jl( xx_jl, length );;
bubble_sort_jl( xx_jl, length );;
time;