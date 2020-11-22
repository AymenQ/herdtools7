(****************************************************************************)
(*                           the diy toolsuite                              *)
(*                                                                          *)
(* Jade Alglave, University College London, UK.                             *)
(* Luc Maranget, INRIA Paris-Rocquencourt, France.                          *)
(*                                                                          *)
(* Copyright 2017-present Institut National de Recherche en Informatique et *)
(* en Automatique and the authors. All rights reserved.                     *)
(*                                                                          *)
(* This software is governed by the CeCILL-B license under French law and   *)
(* abiding by the rules of distribution of free software. You can use,      *)
(* modify and/ or redistribute the software under the terms of the CeCILL-B *)
(* license as circulated by CEA, CNRS and INRIA at the following URL        *)
(* "http://www.cecill.info". We also give a copy in LICENSE.txt.            *)
(****************************************************************************)

module UInt128Scalar = struct
  open Uint
  include Uint128

  let shift_right_arithmetic = Uint128.shift_right

  let addk x k = match k with
  | 0 -> x
  | 1 -> succ x
  | _ -> add x (of_int k)

  let machsize = MachSize.S128
  let pp hexa v =
    Printf.sprintf "%s" (if hexa then (Uint128.to_string_hex v) else (Uint128.to_string v))
  let lt v1 v2 = compare v1 v2 < 0
  let le v1 v2 = compare v1 v2 <= 0
  let bit_at k v = Uint128.logand v (Uint128.shift_left Uint128.one k)
  let mask sz =
    let open MachSize in
    match sz with
    | Byte -> fun v -> Uint128.logand v (Uint128.of_uint8 Uint8.max_int)
    | Short -> fun v -> Uint128.logand v (Uint128.of_uint16 Uint16.max_int)
    | Word -> fun v ->  Uint128.logand v (Uint128.of_uint32 Uint32.max_int)
    | Quad -> fun v -> Uint128.logand v (Uint128.of_uint64 Uint64.max_int)
    | S128 -> fun v -> v

  let get_tag _ = assert false
  let set_tag _ = assert false
end

include SymbConstant.Make(UInt128Scalar)