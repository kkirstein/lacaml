(* File: mat_SDCZ.ml

   Copyright (C) 2002-

     Markus Mottl
     email: markus.mottl@gmail.com
     WWW: http://www.ocaml.info

     Christophe Troestler
     email: Christophe.Troestler@umons.ac.be
     WWW: http://math.umh.ac.be/an/

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*)

open Printf
open Bigarray
open Numberxx
open Utils

(* Creation of matrices *)

let create m n = Array2.create prec fortran_layout m n

let make m n x =
  let mat = create m n in
  Array2.fill mat x;
  mat

let make0 m n = make m n zero

let of_array ar = Array2.of_array prec fortran_layout ar

let init_rows m n f =
  let mat = create m n in
  for row = 1 to m do
    for col = 1 to n do
      mat.{row, col} <- f row col
    done
  done;
  mat

let init_cols m n f =
  let mat = create m n in
  for col = 1 to n do
    for row = 1 to m do
      mat.{row, col} <- f row col
    done
  done;
  mat

let create_mvec m = create m 1

let make_mvec m x = make m 1 x

let mvec_of_array ar =
  let n = Array.length ar in
  let mat = create_mvec n in
  if n <> 0 then
    for row = 1 to n do mat.{row, 1} <- ar.(row - 1) done;
  mat

let mvec_to_array (mat : mat) =
  let n = Array2.dim1 mat in
  if n = 0 then [||]
  else
    let ar = Array.make n mat.{1, 1} in
    for row = 2 to n do ar.(row - 1) <- mat.{row, 1} done;
    ar

let from_col_vec vec = reshape_2 (genarray_of_array1 vec) (Array1.dim vec) 1
let from_row_vec vec = reshape_2 (genarray_of_array1 vec) 1 (Array1.dim vec)

let empty = create 0 0

let identity n =
  let mat = make n n zero in
  for i = 1 to n do mat.{i, i} <- one done;
  mat

let of_diag vec =
  let n = Array1.dim vec in
  let mat = make n n zero in
  for i = 1 to n do mat.{i, i} <- vec.{i} done;
  mat

let dim1 (mat : mat) = Array2.dim1 mat
let dim2 (mat : mat) = Array2.dim2 mat

let to_array mat =
  let m = dim1 mat in
  let n = dim2 mat in
  if m = 0 then [||]
  else if n = 0 then Array.make m [||]
  else
    let ar = Array.make_matrix m n mat.{1, 1} in
    for row = 1 to m do
      let row_ar = ar.(row - 1) in
      for col = 1 to n do row_ar.(col - 1) <- mat.{row, col} done;
    done;
    ar

let diag mat =
  let m = dim1 mat in
  let n = dim2 mat in
  let n_diag = min m n in
  let vec = Array1.create prec fortran_layout n_diag in
  for i = 1 to n_diag do vec.{i} <- mat.{i, i} done;
  vec

let col (mat : mat) c = Array2.slice_right mat c

let copy_row ?vec mat r =
  let n = dim2 mat in
  let vec =
    match vec with
    | Some vec ->
        if Array1.dim vec < n then
          failwith ("copy_row: dim(vec) < " ^ string_of_int n);
        vec
    | None -> Array1.create prec fortran_layout n in
  for c = 1 to n do vec.{c} <- mat.{r, c} done;
  vec

external direct_copy :
  n : int ->
  ofsy : int ->
  incy : int ->
  y : vec ->
  ofsx : int ->
  incx : int ->
  x : vec ->
  unit = "lacaml_NPRECcopy_stub_bc" "lacaml_NPRECcopy_stub"

let of_col_vecs ar =
  let n = Array.length ar in
  if n = 0 then create 0 0
  else
    let m = Array1.dim ar.(0) in
    let mat = create m n in
    for c = 1 to n do
      let vec = ar.(c - 1) in
      if Array1.dim vec <> m then
        failwith "of_col_vecs: vectors not of same length";
      direct_copy ~n:m ~ofsy:1 ~incy:1 ~y:(col mat c) ~ofsx:1 ~incx:1 ~x:vec
    done;
    mat

let to_col_vecs mat =
  let n = dim2 mat in
  if n = 0 then [||]
  else
    let ar = Array.make n (col mat 1) in
    for i = 2 to n do ar.(i - 1) <- col mat i done;
    ar

let transpose ?m ?n ?(ar = 1) ?(ac = 1) a =
  let loc = "Lacaml.Impl.NPREC.Mat.transpose" in
  let m = get_dim1_mat loc a_str a ar m_str m in
  let n = get_dim2_mat loc a_str a ac n_str n in
  let res = create n m in
  for col = 1 to n do
    for row = 1 to m do res.{col, row} <- a.{ar + row - 1, ac + col - 1} done
  done;
  res

let detri ?(up = true) ?n ?(ar = 1) ?(ac = 1) a =
  let loc = "Lacaml.Impl.NPREC.Mat.detri" in
  let n = get_n_of_square a_str loc ar ac a n in
  if up then
    for c = 1 to n - 1 do
      let ar_c = ar + c in
      let ac_c = ac + c in
      for r = 0 to c - 1 do
        a.{ar_c, ac + r} <- a.{ar + r, ac_c}
      done
    done
  else
    for c = 1 to n - 1 do
      let ar_c = ar + c in
      let ac_c = ac + c in
      for r = 0 to c - 1 do
        a.{ar + r, ac_c} <- a.{ar_c, ac + r}
      done
    done

let packed ?(up = true) ?n ?(ar = 1) ?(ac = 1) a =
  let loc = "Lacaml.Impl.NPREC.Mat.packed" in
  let n = get_n_of_square a_str loc ar ac a n in
  let dst = Array1.create prec fortran_layout ((n * n + n) / 2) in
  let pos_ref = ref 1 in
  if up then
    for c = 1 to n do
      for r = 1 to c do
        dst.{!pos_ref} <- a.{r, c};
        incr pos_ref;
      done
    done
  else
    for c = 1 to n do
      for r = c to n do
        dst.{!pos_ref} <- a.{r, c};
        incr pos_ref;
      done
    done;
  dst

let unpacked ?(up = true) ?n src =
  let loc = "Lacaml.Impl.NPREC.Mat.unpacked" in
  let n = get_unpacked_dim loc ?n (Array1.dim src) in
  let a = make0 n n in
  let pos_ref = ref 1 in
  if up then
    for c = 1 to n do
      for r = 1 to c do
        a.{r, c} <- src.{!pos_ref};
        incr pos_ref;
      done
    done
  else
    for c = 1 to n do
      for r = c to n do
        a.{r, c} <- src.{!pos_ref};
        incr pos_ref;
      done
    done;
  a

external direct_scal_mat :
  m : int ->
  n : int ->
  alpha : num_type ->
  ar : int ->
  ac : int ->
  a : mat ->
  unit = "lacaml_NPRECscal_mat_stub_bc" "lacaml_NPRECscal_mat_stub"

let scal ?m ?n alpha ?(ar = 1) ?(ac = 1) a =
  let loc = "Lacaml.Impl.NPREC.Mat.scal" in
  let m = get_dim1_mat loc a_str a ar m_str m in
  let n = get_dim2_mat loc a_str a ac n_str n in
  direct_scal_mat ~m ~n ~alpha ~ar ~ac ~a

external direct_scal_cols :
  m : int ->
  n : int ->
  ofs : int ->
  alphas : vec ->
  ar : int ->
  ac : int ->
  a : mat ->
  unit = "lacaml_NPRECscal_cols_stub_bc" "lacaml_NPRECscal_cols_stub"

let scal_cols ?m ?n ?ofs alphas ?(ar = 1) ?(ac = 1) a =
  let loc = "Lacaml.Impl.NPREC.Mat.scal_cols" in
  let m = get_dim1_mat loc a_str a ar m_str m in
  let n = get_dim2_mat loc a_str a ac n_str n in
  let ofs = get_ofs loc alphas_str ofs in
  ignore (get_dim_vec loc alphas_str ofs 1 alphas n_str (Some n));
  direct_scal_cols ~m ~n ~ofs ~alphas ~ar ~ac ~a

external direct_mat_axpy :
  m : int ->
  n : int ->
  alpha : num_type ->
  xr : int ->
  xc : int ->
  x : mat ->
  yr : int ->
  yc : int ->
  y : mat ->
  unit = "lacaml_NPRECmat_axpy_stub_bc" "lacaml_NPRECmat_axpy_stub"

let axpy ?m ?n ?(alpha = one) ?(xr = 1) ?(xc = 1) ~x ?(yr = 1) ?(yc = 1) y =
  let loc = "Lacaml.Impl.NPREC.Mat.axpy" in
  let m = get_dim1_mat loc x_str x xr m_str m in
  let n = get_dim2_mat loc x_str x xc n_str n in
  check_dim_mat loc y_str yr yc y m n;
  direct_mat_axpy ~m ~n ~alpha ~xr ~xc ~x ~yr ~yc ~y

let vec_create n = Array1.create prec fortran_layout n

external direct_gemm_diag :
  transa : char ->
  transb : char ->
  n : int ->
  k : int ->
  ar : int ->
  ac : int ->
  a : mat ->
  br : int ->
  bc : int ->
  b : mat ->
  ofsy : int ->
  y : vec ->
  alpha : num_type ->
  beta : num_type ->
  unit = "lacaml_NPRECgemm_diag_stub_bc" "lacaml_NPRECgemm_diag_stub"

let gemm_diag ?n ?k ?(beta = zero) ?(ofsy = 1) ?y
  ?(transa = `N) ?(alpha = one) ?(ar = 1) ?(ac = 1) a
  ?(transb = `N) ?(br = 1) ?(bc = 1) b =
  let loc = "Lacaml.Impl.NPREC.Mat.gemm_diag" in
  let n = get_rows_mat_tr loc a_str a ar ac transa n_str n in
  let n = get_cols_mat_tr loc b_str b br bc transb n_str (Some n) in
  let k = get_inner_dim loc a_str a ar ac transa b_str b br bc transb k_str k in
  let transa = get_trans_char transa in
  let transb = get_trans_char transb in
  let y = get_vec loc y_str y ofsy 1 n vec_create in
  direct_gemm_diag
    ~transa ~transb ~n ~k ~ar ~ac ~a ~br ~bc ~b ~ofsy ~y ~alpha ~beta;
  y

external direct_syrk_diag :
  trans : trans3 ->
  n : int ->
  k : int ->
  ar : int ->
  ac : int ->
  a : mat ->
  ofsy : int ->
  y : vec ->
  alpha : num_type ->
  beta : num_type ->
  unit = "lacaml_NPRECsyrk_diag_stub_bc" "lacaml_NPRECsyrk_diag_stub"

let syrk_diag ?n ?k ?(beta = zero) ?(ofsy = 1) ?y
  ?(trans = `N) ?(alpha = one) ?(ar = 1) ?(ac = 1) a =
  let loc = "Lacaml.Impl.NPREC.Mat.syrk_diag" in
  let n = get_rows_mat_tr loc a_str a ar ac trans n_str n in
  let k = get_cols_mat_tr loc a_str a ar ac trans k_str k in
  let y = get_vec loc y_str y ofsy 1 n vec_create in
  direct_syrk_diag ~trans ~n ~k ~ar ~ac ~a ~ofsy ~y ~alpha ~beta;
  y

external direct_gemm_trace :
  transa : char ->
  transb : char ->
  n : int ->
  k : int ->
  ar : int ->
  ac : int ->
  a : mat ->
  br : int ->
  bc : int ->
  b : mat ->
  num_type = "lacaml_NPRECgemm_trace_stub_bc" "lacaml_NPRECgemm_trace_stub"

let gemm_trace ?n ?k ?(transa = `N) ?(ar = 1) ?(ac = 1) a
  ?(transb = `N) ?(br = 1) ?(bc = 1) b =
  let loc = "Lacaml.Impl.NPREC.Mat.gemm_trace" in
  let n = get_rows_mat_tr loc a_str a ar ac transa n_str n in
  let n = get_cols_mat_tr loc b_str b br bc transb n_str (Some n) in
  let k = get_inner_dim loc a_str a ar ac transa b_str b br bc transb k_str k in
  let transa = get_trans_char transa in
  let transb = get_trans_char transb in
  direct_gemm_trace ~transa ~transb ~n ~k ~ar ~ac ~a ~br ~bc ~b


(* Iterators over matrices *)

let map f ?m ?n ?(br = 1) ?(bc = 1) ?b ?(ar = 1) ?(ac = 1) a =
  let loc = "Lacaml.Impl.NPREC.Mat.map" in
  let m = get_dim1_mat loc a_str a ar m_str m in
  let n = get_dim2_mat loc a_str a ac n_str n in
  let b, br, bc =
    match b with
    | None -> create m n, 1, 1
    | Some b -> check_dim_mat loc c_str br bc b m n; b, br, bc
  in
  let max_row = m - 1 in
  for i = 0 to n - 1 do
    for j = 0 to max_row do b.{br + j, bc + i} <- f a.{ar + j, ac + i} done;
  done;
  b

let fold_cols coll ?n ?(ac = 1) acc a =
  let loc = "Lacaml.Impl.NPREC.Mat.fold_cols" in
  let n = get_dim2_mat loc a_str a ac n_str n in
  let acc_ref = ref acc in
  for i = 0 to n - 1 do acc_ref := coll !acc_ref (col a (ac + i)) done;
  !acc_ref
