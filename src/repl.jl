import REPL
import REPL: LineEdit, REPLCompletions

function CreateGAPREPL(; prompt = "gap> ", name = :gap, repl = Base.active_repl, main_mode = repl.interface.modes[1])
   mirepl = isdefined(repl,:mi) ? repl.mi : repl
   # Setup GAP panel
   panel = LineEdit.Prompt(prompt;
        # Copy colors from the prompt object
        prompt_prefix=Base.text_colors[:blue],
        prompt_suffix=Base.text_colors[:red],
        on_enter = REPL.return_callback)
        #on_enter = s->isExpressionComplete(C,push!(copy(LineEdit.buffer(s).data),0)))

   panel.on_done = REPL.respond(repl,panel; pass_empty = false) do line
       if !isempty(line)
           :(GAP.EvalString($line) )
       else
           :(  )
       end
   end

   main_mode == mirepl.interface.modes[1] &&
       push!(mirepl.interface.modes,panel)

   # 0.7 compat
   if isdefined(main_mode, :repl)
       panel.repl = main_mode.repl
   end

   hp = main_mode.hist
   hp.mode_mapping[name] = panel
   panel.hist = hp

   search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
   mk = REPL.mode_keymap(main_mode)

   b = Dict{Any,Any}[skeymap, mk, LineEdit.history_keymap, LineEdit.default_keymap, LineEdit.escape_defaults]
   panel.keymap_dict = LineEdit.keymap(b)

   panel
end

global function run_gap_repl(; prompt = "gap> ", name = :gap, key = '$')
   repl = Base.active_repl
   mirepl = isdefined(repl,:mi) ? repl.mi : repl
   main_mode = mirepl.interface.modes[1]

   panel = CreateGAPREPL(; prompt=prompt, name=name, repl=repl)

    # Install this mode into the main mode
    gap_keymap = Dict{Any,Any}(
        key => function (s,args...)
            if isempty(s) || position(LineEdit.buffer(s)) == 0
                buf = copy(LineEdit.buffer(s))
                LineEdit.transition(s, panel) do
                    LineEdit.state(s, panel).input_buffer = buf
                end
            else
                LineEdit.edit_insert(s,key)
            end
        end
    )
    main_mode.keymap_dict = LineEdit.keymap_merge(main_mode.keymap_dict, gap_keymap);
    nothing
end