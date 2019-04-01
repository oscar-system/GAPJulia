#############################################################################
##
##  JuliaInterface package
##
##  Copyright 2019
##    Thomas Breuer, RWTH Aachen University
##    Sebastian Gutsche, Siegen University
##
#############################################################################

DeclareGlobalVariable( "_JULIAINTERFACE_TRANSPILER_REC" );

BindGlobal( "DISPATCH_EXPRESSION",
  function( record )
    if IsList( record ) and not IsString( record ) then
        return _JULIAINTERFACE_TRANSPILER_REC.list( record );
    fi;
    if not IsRecord( record ) then
        return record;
    fi;
    return _JULIAINTERFACE_TRANSPILER_REC.(record.type)( record );
end );

BindGlobal( "CREATE_EXPRESSION1",
  function( type, args... )
    local argument_expr, i;
    argument_expr := [ ];
    for i in [ 1 .. Length( args ) ] do
        argument_expr[ i + 1 ] := DISPATCH_EXPRESSION( args[ i ] );
    od;
    argument_expr[ 1 ] := GAPToJulia( Julia.Base.Symbol, type );
    return CallFuncList( Julia.Base.Expr, argument_expr );
end );

BindGlobal( "CREATE_EXPRESSION2",
  function( type, symb, args... )
    local argument_expr, i;
    argument_expr := [ ];
    for i in [ 1 .. Length( args ) ] do
        argument_expr[ i + 2 ] := DISPATCH_EXPRESSION( args[ i ] );
    od;
    argument_expr[ 1 ] := GAPToJulia( Julia.Base.Symbol, type );
    argument_expr[ 2 ] := GAPToJulia( Julia.Base.Symbol, symb );
    return CallFuncList( Julia.Base.Expr, argument_expr );
end );

BindGlobal( "SYMBOL_LVAR",
    i -> GAPToJulia( Julia.Base.Symbol, Concatenation( "localvar_", String( i ) ) ) );

BindGlobal( "TRANSPILE_LIST", function( list )
    local stats;
    stats := List( list, DISPATCH_EXPRESSION );
    return CallFuncList( CREATE_EXPRESSION1, Concatenation( [ "block" ], stats ) );
end );

BindGlobal( "TRANSPILE_SEQ_STAT",
  function( node )
    return TRANSPILE_LIST( node.statements );
end );

BindGlobal( "TRANSPILE_RANGE", function( node )
    local first, last;
    first := DISPATCH_EXPRESSION( node.first );
    last := DISPATCH_EXPRESSION( node.last );
    return CREATE_EXPRESSION2( "call", ":", first, last );
end );

BindGlobal( "TRANSPILE_FOR", function( node )
    local variable, collection, head, body;
    variable := DISPATCH_EXPRESSION( node.variable );
    collection := DISPATCH_EXPRESSION( node.collection );
    head := CREATE_EXPRESSION1( "=", variable, collection );
    body := DISPATCH_EXPRESSION( node.body );
    return CREATE_EXPRESSION1( "for", head, body );
end );

BindGlobal( "TRANSPILE_IF", function( node )
    local nr_branches, last_branch_else, branches, current_expr,
          last_branch, current_branch;
    if node!.type = "T_IF" then
        nr_branches := 1;
        last_branch_else := false;
    elif node!.type = "T_IF_ELIF" then
        nr_branches := Length( node!.branches );
        last_branch_else := false;
    elif node!.type = "T_IF_ELSE" then
        nr_branches := 2;
        last_branch_else := true;
    elif node!.type = "T_IF_ELIF_ELSE" then
        nr_branches := Length( node!.branches );
        last_branch_else := true;
    fi;

    branches := ShallowCopy( node!.branches );
    
    current_expr := false;

    if nr_branches > 1 then
        ## start with the last elseif/else
        last_branch := branches[ nr_branches ];
        if last_branch_else then
            current_expr := CREATE_EXPRESSION1( "block", last_branch!.body );
        else
            current_expr := CREATE_EXPRESSION1( "elseif", last_branch!.condition, last_branch!.body );
        fi;

        ## traverse from back
        current_branch := nr_branches - 1;
        while current_branch > 1 do
            current_expr := CREATE_EXPRESSION1( "elseif", branches[ current_branch ].condition, branches[ current_branch.body ], current_expr );
            current_branch := current_branch - 1;
        od;
    fi;

    if current_expr <> false then
        current_expr := CREATE_EXPRESSION1( "if", branches[ 1 ].condition, branches[ 1 ].body, current_expr );
    else
        current_expr := CREATE_EXPRESSION1( "if", branches[ 1 ].condition, branches[ 1 ].body );
    fi;
    
    return current_expr;

end );

BindGlobal( "TRANSPILE_REC", function( node )
    local pairs, function_for_key;

    pairs := node.keyvalue;
    function_for_key := function( key )
        if IsString( key ) then
            return GAPToJulia( JuliaEvalString( "Symbol" ), key );
        else
            return key;
        fi;
    end;

    pairs := List( pairs, i -> CREATE_EXPRESSION2( "call", "=>", function_for_key( i.key ), i.value ) );

    return CallFuncList( CREATE_EXPRESSION2, Concatenation( [ "call", "Dict" ], pairs ) );

end );


InstallValue( _JULIAINTERFACE_TRANSPILER_REC, rec( 

    # T_PROCCALL

    # T_EMPTY

    T_SEQ_STAT := TRANSPILE_SEQ_STAT,
    T_SEQ_STAT2 := TRANSPILE_SEQ_STAT,
    T_SEQ_STAT3 := TRANSPILE_SEQ_STAT,
    T_SEQ_STAT4 := TRANSPILE_SEQ_STAT,
    T_SEQ_STAT5 := TRANSPILE_SEQ_STAT,
    T_SEQ_STAT6 := TRANSPILE_SEQ_STAT,
    T_SEQ_STAT7 := TRANSPILE_SEQ_STAT,

    T_IF := TRANSPILE_IF,
    T_IF_ELSE := TRANSPILE_IF,
    T_IF_ELIF := TRANSPILE_IF,
    T_IF_ELIF_ELSE := TRANSPILE_IF,

    T_FOR := TRANSPILE_FOR,
    T_FOR2 := TRANSPILE_FOR,
    T_FOR3 := TRANSPILE_FOR,
    T_FOR_RANGE := TRANSPILE_FOR,
    T_FOR_RANGE2 := TRANSPILE_FOR,
    T_FOR_RANGE3 := TRANSPILE_FOR,

    # T_WHILE

    # T_REPEAT

    # T_ATOMIC

    T_BREAK := node -> CREATE_EXPRESSION1( "break" ),
    T_CONTINUE := node -> CREATE_EXPRESSION1( "continue" ),

    T_RETURN_OBJ := node -> CREATE_EXPRESSION1( "return", node!.obj ),
    T_RETURN_VOID := node -> CREATE_EXPRESSION1( "return", Julia.Base.nothing ),

    T_ASS_LVAR := node -> CREATE_EXPRESSION1( "=", SYMBOL_LVAR( node.lvar ), node.rhs ),
    # T_UNB_LVAR

    # T_ASS_HVAR
    # T_UNB_HVAR

    # T_ASS_GVAR
    # T_UNB_GVAR

    T_ASS_LIST := node -> CREATE_EXPRESSION1( "=", CREATE_EXPRESSION1( "ref", node!.list, node!.pos ), node!.rhs ),
    # T_ASS2_LIST...

    # T_ASS_REC_NAME

    # T_ASS_POSOBJ

    # T_ASS_COMOBJ

    # T_INFO
    # T_ASSERT

    # T_FUNCCALL

    # T_FUNC_EXPR

    T_OR := node -> CREATE_EXPRESSION1( "||", node.left, node.right ),
    T_AND := node -> CREATE_EXPRESSION1( "&&", node.left, node.right ),
    T_NOT := node -> CREATE_EXPRESSION2( "call", "!", node.op ),
    T_EQ := node -> CREATE_EXPRESSION2( "call", "==", node.left, node.right ),
    T_NE := node -> CREATE_EXPRESSION2( "call", "!=", node.left, node.right ),
    T_LT := node -> CREATE_EXPRESSION2( "call", "<", node.left, node.right ),
    T_GE := node -> CREATE_EXPRESSION2( "call", ">=", node.left, node.right ),
    T_GT := node -> CREATE_EXPRESSION2( "call", ">", node.left, node.right ),
    T_LE := node -> CREATE_EXPRESSION2( "call", "<=", node.left, node.right ),
    T_IN := node -> CREATE_EXPRESSION2( "call", "in", node.left, node.right ),
    T_SUM := node -> CREATE_EXPRESSION2( "call", "+", node.left, node.right ),
    T_AINV := node -> CREATE_EXPRESSION2( "call", "-", node.op ),
    T_DIFF := node -> CREATE_EXPRESSION2( "call", "-", node.left, node.right ),
    T_PROD := node -> CREATE_EXPRESSION2( "call", "*", node.left, node.right ),
    ## Fixme: // or /
    T_QUO := node -> CREATE_EXPRESSION2( "call", "//", node.left, node.right ),
    T_MOD := node -> CREATE_EXPRESSION2( "call", "%", node.left, node.right ),
    T_POW := node -> CREATE_EXPRESSION2( "call", "^", node.left, node.right ),

    T_INTEXPR := node -> node.value,
    T_INT_EXPR := node -> JuliaToGAP( node.value ),

    T_TRUE_EXPR := node -> true,
    T_FALSE_EXPR := node -> false,

    # T_TILDE_EXPR
    # T_CHAR_EXPR
    # T_PERM_EXPR
    # T_LIST_EXPR

    T_REC_EXPR := TRANSPILE_REC,

    T_RANGE_EXPR := TRANSPILE_RANGE,

    T_STRING_EXPR := node -> JuliaToGAP( node.value ),

    T_REFLVAR := node -> SYMBOL_LVAR( node.lvar ),

    T_ELM_LIST := node -> CREATE_EXPRESSION1( "ref", node!.list, node!.pos ),


    ## Dummies
    list := TRANSPILE_LIST,

) );

BindGlobal( "TRANSPILE_FUNC",
  function( func )
    local nr_args, arg_expr, exprs, tree;
    tree := SYNTAX_TREE( func );
    nr_args := tree!.narg;
    arg_expr := List( [ 1 .. nr_args ], SYMBOL_LVAR );
    arg_expr := CallFuncList( CREATE_EXPRESSION1, Concatenation( [ "tuple" ], arg_expr ) );
    exprs := [ "function", arg_expr, DISPATCH_EXPRESSION( tree.stats ) ];
    return CallFuncList( CREATE_EXPRESSION1, exprs );
end );