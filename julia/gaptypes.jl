# ATM, this causes more problems than it serves.
# There is no arithmetic installed for Ptr{Void}

# struct GapObj
#     ptr::Ptr{Void}
# end

module GAPUtils

function get_function_symbols_in_module(module_t)
    list = filter(i->isdefined(module_t,i) && isa(eval((:($module_t.$i))),Function),names(module_t))
    return list
end

function get_variable_symbols_in_module(module_t)
    list = filter(i->isdefined(module_t,i) && ! isa(eval((:($module_t.$i))),Function),names(module_t))
    return list
end

export get_function_symbols_in_module, get_variable_symbols_in_module

end

module GAP

import Base: +

export gap_funcs, prepare_func_for_gap, GapObj, GapFunc, gap_object_finalizer, GAPRat, get_gaprat_ptr

gap_funcs = Array{Any,1}();

gap_object_finalizer = function(obj)
    ccall(Main.gap_unpin_gap_obj,Void,(Cint,),obj.index)
end

mutable struct GapObj
    ptr::Ptr{Void}
    index
    function GapObj(ptr::Ptr{Void})
        index = ccall(Main.gap_pin_gap_obj,Cint,(Ptr{Void},),ptr)
        new_obj = new(ptr,index)
        finalizer(new_obj,gap_object_finalizer)
        return new_obj
    end
end

struct GapFunc
    ptr::Ptr{Void}
end

struct GAPRat
    obj::GapObj
end

function GAPRat(ptr::Ptr{Void})
    return GAPRat(GapObj(ptr))
end

function +(a::GAPRat,b::GAPRat)
    ptr = ccall(Main.gap_MyFuncSUM,Ptr{Void},(Ptr{Void},Ptr{Void}),a.obj.ptr,b.obj.ptr)
    return GAPRat(GapObj(ptr))
end

function get_gaprat_ptr(a::GAPRat)
    return a.obj.ptr
end

function(func::GapFunc)(args...)
    arg_array = collect(args)
    arg_array = map(i->i.ptr,arg_array)
    length_array = length(arg_array)
    gap_arg_list = GapObj(ccall(Main.gap_MakeGapArgList,Ptr{Void},
                                (Cint,Ptr{Ptr{Void}}),length_array,arg_array))
    return GapObj(ccall(Main.gap_CallFuncList,Ptr{Void},
                        (Ptr{Void},Ptr{Void}),func.ptr,gap_arg_list.ptr))
end

function prepare_func_for_gap(gap_func)
    return_func = function(self,args...)
        new_args = map(GapObj,args)
        return_value = gap_func(new_args...)
        return return_value.ptr
    end
    push!(gap_funcs,return_func)
    return return_func
end

end
