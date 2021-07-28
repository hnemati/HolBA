structure birprogjsonexportLib =
struct
local
  open HolKernel Parse boolLib bossLib;

  open bir_programSyntax;

  open bir_expSyntax bir_immSyntax bir_envSyntax bir_exp_immSyntax bir_exp_memSyntax;
  open bir_valuesSyntax;
  open wordsSyntax;

  open listSyntax;

  (* error handling *)
  val libname = "birprogjsonexportLib"
  val ERR = Feedback.mk_HOL_ERR libname
  val wrap_exn = Feedback.wrap_exn libname

  fun problem_gen fname t msg = 
    raise ERR fname (msg ^ (term_to_string t));

in

  fun bvar_to_json bv =
    let
      fun problem exp msg = problem_gen "bvar_to_json" exp msg;

      val sname = (fst o dest_BVar_string) bv;
      val vty   = (snd o dest_BVar_string) bv;
      val stype =
       if is_BType_Imm1  vty then "imm1"  else
       if is_BType_Imm8  vty then "imm8"  else
       if is_BType_Imm16 vty then "imm16" else
       if is_BType_Imm32 vty then "imm32" else
       if is_BType_Imm64 vty then "imm64" else
       if is_BType_Mem vty then 
        if pair_eq identical identical (dest_BType_Mem vty) (Bit32_tm, Bit8_tm) then "mem_32_8" else
        if pair_eq identical identical (dest_BType_Mem vty) (Bit64_tm, Bit8_tm) then "mem_64_8" else
        problem bv "unhandled variable type: "
        else
       problem bv "unhandled variable type: ";
    in
          Json.OBJECT [("name", Json.STRING sname), ("type", Json.STRING stype)]
    end;

  fun bexp_to_json exp =
    let
      fun problem exp msg = problem_gen "bexp_to_json" exp msg;
    in
      if is_BExp_Const exp then
        let
          val (sz, wv) = (gen_dest_Imm o dest_BExp_Const) exp;
          val vstr =
            if is_word_literal wv then
              (Arbnum.toString o dest_word_literal) wv
            else problem exp "can only handle word literals: ";
        in
          Json.OBJECT [("exptype", Json.STRING "const"), ("val", Json.STRING vstr), ("sz", Json.STRING (Int.toString sz))]
        end

      else if is_BExp_Den exp then
        let
          val bv    = dest_BExp_Den exp;
        in
          Json.OBJECT [("exptype", Json.STRING "var"), ("var", bvar_to_json bv)]
        end

      else if is_BExp_Cast exp then
        let
          val (castt, exp, sz) = (dest_BExp_Cast) exp;
          val exp_json = bexp_to_json exp;

          val szi = size_of_bir_immtype_t sz;

          val caststr = term_to_string castt;
        in
          Json.OBJECT [("exptype", Json.STRING "cast"), ("type", Json.STRING caststr), ("exp", exp_json), ("sz", Json.STRING (Int.toString szi))]
        end

      else if is_BExp_UnaryExp exp then
        let
          val (uop, exp) = (dest_BExp_UnaryExp) exp;
          val exp_json = bexp_to_json exp;
          val uopstr = term_to_string uop;
        in
          Json.OBJECT [("exptype", Json.STRING "uop"), ("type", Json.STRING uopstr), ("exp", exp_json)]
        end

      else if is_BExp_BinExp exp then
        let
          val (bop, exp1, exp2) = (dest_BExp_BinExp) exp;
          val exp1_json = bexp_to_json exp1;
          val exp2_json = bexp_to_json exp2;
          val bopstr = term_to_string bop;
        in
          Json.OBJECT [("exptype", Json.STRING "bop"), ("type", Json.STRING bopstr), ("exp1", exp1_json), ("exp2", exp2_json)]
        end

      else if is_BExp_BinPred exp then
        let
          val (bpredop, exp1, exp2) = (dest_BExp_BinPred) exp;
          val exp1_json = bexp_to_json exp1;
          val exp2_json = bexp_to_json exp2;
          val bpredopstr = term_to_string bpredop;
        in
          Json.OBJECT [("exptype", Json.STRING "bpredop"), ("type", Json.STRING bpredopstr), ("exp1", exp1_json), ("exp2", exp2_json)]
        end

      else if is_BExp_IfThenElse exp then
        let
          val (expc, expt, expf) = (dest_BExp_IfThenElse) exp;
          val expc_json = bexp_to_json expc;
          val expt_json = bexp_to_json expt;
          val expf_json = bexp_to_json expf;
        in
          Json.OBJECT [("exptype", Json.STRING "ite"), ("cond", expc_json), ("then", expt_json), ("else", expf_json)]
        end

      else if is_BExp_Load exp then
        let
          val (expm, expad, endi, sz) = (dest_BExp_Load) exp;

          val expm_json  = bexp_to_json expm;
          val expad_json = bexp_to_json expad;

          val endi_str = term_to_string endi;
          val sz_str = term_to_string sz;
        in
          Json.OBJECT [("exptype", Json.STRING "load"), ("mem", expm_json), ("addr", expad_json), ("endi", Json.STRING endi_str), ("sz", Json.STRING sz_str)]
        end

      else if is_BExp_Store exp then
        let
          val (expm, expad, endi, expv) = (dest_BExp_Store) exp;

          val expm_json  = bexp_to_json expm;
          val expad_json = bexp_to_json expad;

          val endi_str = term_to_string endi;

          val expv_json  = bexp_to_json expv;
        in
          Json.OBJECT [("exptype", Json.STRING "load"), ("mem", expm_json), ("addr", expad_json), ("endi", Json.STRING endi_str), ("val", expv_json)]
        end

      else
        problem exp "don't know BIR expression: "
        (*Json.STRING (term_to_string exp)*)
    end;



  fun estmttojson estmt =
    if is_BStmt_Halt estmt then
      Json.OBJECT [("estmttype", Json.STRING "HALT"), ("exp", bexp_to_json (dest_BStmt_Halt estmt))]
    else if is_BStmt_Jmp estmt then
      Json.OBJECT [("estmttype", Json.STRING "JMP"), ("lbl", Json.STRING (term_to_string (dest_BStmt_Jmp estmt)))]
    else if is_BStmt_CJmp estmt then
      let
        val (cnd_tm, lblet_tm, lblef_tm) = dest_BStmt_CJmp estmt;
      in
        Json.OBJECT [("estmttype", Json.STRING "CJMP"),
                     ("cnd", bexp_to_json cnd_tm),
                     ("lblt", Json.STRING (term_to_string lblet_tm)),
                     ("lblf", Json.STRING (term_to_string lblef_tm))]
      end
    else
      raise ERR "estmttojson" ("unknown end statement type: " ^ (term_to_string estmt));


  fun stmttojson stmt =
    if is_BStmt_Assign stmt then
      let
        val (var_tm, exp_tm) = dest_BStmt_Assign stmt;
      in
        Json.OBJECT [("stmttype", Json.STRING "ASSIGN"),
                     ("var", bvar_to_json var_tm),
                     ("exp", bexp_to_json exp_tm)]
      end
    else if is_BStmt_Assert stmt then
      Json.OBJECT [("stmttype", Json.STRING "ASSERT"), ("exp", bexp_to_json (dest_BStmt_Assert stmt))]
    else if is_BStmt_Assume stmt then
      Json.OBJECT [("stmttype", Json.STRING "ASSUME"), ("exp", bexp_to_json (dest_BStmt_Assume stmt))]
    else if is_BStmt_Observe stmt then
      let
        val (id_tm, cnd_tm, obss_tm, obsf_tm) = dest_BStmt_Observe stmt;

        val obs_tm_list = (fst o dest_list) obss_tm;
        val obs_json_list = List.map bexp_to_json obs_tm_list;
      in
        Json.OBJECT [("stmttype", Json.STRING "OBSERVE"),
                     ("id", Json.STRING (term_to_string id_tm)),
                     ("cnd", bexp_to_json cnd_tm),
                     ("obss", Json.ARRAY obs_json_list),
                     ("obsf", Json.STRING (term_to_string obsf_tm))]
      end
    else
      raise ERR "stmttojson" ("unknown basic statement type: " ^ (term_to_string stmt));


  fun blocktojson block =
    let
      val (tm_lbl, tm_stmts, tm_last_stmt) = dest_bir_block block;

      val tm_stmt_list = (fst o dest_list) tm_stmts;

      val lbl_json  = Json.STRING (term_to_string tm_lbl);
      val stmts_json = Json.ARRAY (List.map stmttojson tm_stmt_list);
      val estmt_json = estmttojson tm_last_stmt;
    in
      Json.OBJECT [("lbl", lbl_json), ("stmts", stmts_json), ("estmt", estmt_json)]
    end;

(*
  val bprog_t = bprog;
*)
  fun birprogtojsonstr bprog_t =
    let
       (* simple normalization to get rid of shorthand definitions from lifter and similar *)
       val bprog_norm_t = (snd o dest_eq o concl o EVAL) bprog_t;

       (* translation to json format (serialize), including term pretty printing for bir expressions and the like *)
       val blocks = (fst o dest_list o dest_BirProgram) bprog_norm_t;

      val addIndents = true;
      val serialize = if addIndents then Json.serialiseIndented else Json.serialise;
    in
      serialize (Json.ARRAY (List.map blocktojson blocks))
    end;


end (* local *)

end (* struct *)
