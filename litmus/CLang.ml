(****************************************************************************)
(*                           the diy toolsuite                              *)
(*                                                                          *)
(* Jade Alglave, University College London, UK.                             *)
(* Luc Maranget, INRIA Paris-Rocquencourt, France.                          *)
(*                                                                          *)
(* Copyright 2010-present Institut National de Recherche en Informatique et *)
(* en Automatique and the authors. All rights reserved.                     *)
(*                                                                          *)
(* This software is governed by the CeCILL-B license under French law and   *)
(* abiding by the rules of distribution of free software. You can use,      *)
(* modify and/ or redistribute the software under the terms of the CeCILL-B *)
(* license as circulated by CEA, CNRS and INRIA at the following URL        *)
(* "http://www.cecill.info". We also give a copy in LICENSE.txt.            *)
(****************************************************************************)

module type Config = sig
  val memory : Memory.t
  val mode : Mode.t
  val comment : string
  val asmcommentaslabel : bool
end

module DefaultConfig = struct
  let memory = Memory.Direct
  let mode = Mode.Std
  let comment = "//"
  let asmcommentaslabel = false
end

module type Target = sig
  type arch_reg
  type code

  type t =
      { inputs : (arch_reg * CType.t) list ;
        finals : arch_reg list ;
        code : code ; }


  val fmt_reg : arch_reg -> string
  val dump_out_reg : int -> arch_reg -> string
  val compile_out_reg : int -> arch_reg -> string
  val compile_presi_out_reg : int -> arch_reg -> string
  val compile_presi_out_ptr_reg : int -> arch_reg -> string
  val get_addrs : t -> string list
  val out_code : out_channel -> code -> unit
end

module Make(C:Config)(Target:Target) = struct
  open Printf

  type arch_reg = Target.arch_reg
  type t = Target.t

  let dump_start chan indent proc =
    if C.asmcommentaslabel then
      fprintf chan
        "%sasm __volatile__ (\"\\n%s:\" ::: \"memory\");\n"
        indent (LangUtils.start_label proc)
    else
      fprintf chan
        "%sasm __volatile__ (\"\\n%s\" ::: \"memory\");\n"
        indent (LangUtils.start_comment C.comment proc)

  let dump_end chan indent proc =
    if C.asmcommentaslabel then
      fprintf chan
        "%sasm __volatile__ (\"\\n%s:\" ::: \"memory\");\n"
        indent (LangUtils.end_label proc)
    else
      fprintf chan
        "%sasm __volatile__ (\"\\n%s\" ::: \"memory\");\n"
        indent (LangUtils.end_comment C.comment proc)

  let dump_global_def env (x,ty) =
    let x = Target.fmt_reg x in
    let pp_ty =  CType.dump ty in
    pp_ty ^ "*",x

  let out_type env x =
    try List.assoc x env
    with Not_found -> assert false

  let dump_output_def env proc x =
    let outname = Target.dump_out_reg proc x
    and ty = out_type env x in
    sprintf "%s*" (CType.dump ty),outname

  let dump_fun chan env globEnv envVolatile proc t =
    let out x = fprintf chan x in
    let input_defs =
      List.map (dump_global_def globEnv) t.Target.inputs
    and output_defs =
      List.map (dump_output_def env proc) t.Target.finals in
    let defs = input_defs@output_defs in
    let params =
      String.concat ","
        (List.map
           (fun (ty,v) -> sprintf "%s %s" ty v)
           defs) in
    (* Function prototype  *)
    LangUtils.dump_code_def chan true proc params ;
    (* body *)
    dump_start chan "  " proc ;
    Target.out_code chan t.Target.code ;
    dump_end chan "  " proc ;
    (* output parameters *)
    List.iter
      (fun reg ->
        out "  *%s = (%s)%s;\n"
          (Target.dump_out_reg proc reg)
          (CType.dump (out_type env reg))
          (Target.fmt_reg reg))
      t.Target.finals ;
    out "}\n\n"


  let dump_call chan indent env globEnv envVolatile proc t =
    let is_array_of a = match List.assoc a globEnv with
    | CType.Array (t,_) -> Some t
    | _ -> None in
    let global_args =
      List.map
        (fun (x,_) ->
          let cast = match is_array_of x with
          | Some t -> sprintf "(%s *)" t
          | None -> "" in
          match C.memory with
        | Memory.Direct ->
            sprintf "%s&_a->%s[_i]" cast (Target.fmt_reg x)
        | Memory.Indirect ->
            sprintf "%s_a->%s[_i]" cast (Target.fmt_reg x))
        t.Target.inputs
    and out_args =
      List.map
        (fun x -> sprintf "&%s" (Target.compile_out_reg proc x))
        t.Target.finals in
    let args = String.concat "," (global_args@out_args) in
    LangUtils.dump_code_call chan indent proc args


  let dump chan indent env globEnv envVolatile proc t =
    let out x = fprintf chan x in
    out "%sdo {\n" indent;
    begin
      let indent = "  " ^ indent in
      let dump_input x =
        let ty,x = dump_global_def globEnv x in
        match C.memory with
        | Memory.Direct -> begin match C.mode with
          | Mode.Std ->
              out "%s%s %s = (%s)&_a->%s[_i];\n" indent ty x ty x
          |  Mode.PreSi -> ()
        end
        | Memory.Indirect ->
            out "%s%s %s = (%s)_a->%s[_i];\n" indent ty x ty x
      in
      let dump_output x =
        let ty = out_type env x in
        match C.mode with
        | Mode.Std ->
            let outname = Target.compile_out_reg proc x in
            out "%s%s = (%s)%s;\n"
              indent outname (CType.dump ty) (Target.fmt_reg x)
        | Mode.PreSi ->
            let outname =
              if CType.is_ptr ty then
                Target.compile_presi_out_ptr_reg proc x
              else
                Target.compile_presi_out_reg proc x in
            out "%s%s = (%s)%s;\n"
              indent outname (CType.dump ty) (Target.fmt_reg x)

      in
      let print_start = dump_start chan in
      let print_end = dump_end chan in
      List.iter dump_input t.Target.inputs;
      print_start indent proc;
      Target.out_code chan t.Target.code ;
      print_end indent proc;
      List.iter dump_output t.Target.finals
    end;
    out "%s} while(0);\n" indent

end
