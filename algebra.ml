open Utility

type base_type = IntType | StrType | BoolType | DecType | DblType | NatType

(* is it necessary to distinguish between float and double?
   should we use 32/64 bit int types, i.e. Int32/Int64? *)
type base_value = 
  | Int of int
  | Str of string
  | Bool of bool
  | Double of float
  | Dec of float
  | Nat of int

(*type aggr = Avg | Max | Min | Sum | Count | Segty1 | All | Prod | Distinct*)

(* aggregate functions *)
type aggr = Avg | Max | Min | Sum

type func = Add | Subtract | Multiply | Divide | Modulo | Contains

(* relation operators *)
type join_comparison = Eq | Gt | Ge | Lt | Le | Ne

type tbl_name = string

(* attribute names *)
type attr_name = string
type result_attr_name = ResultAttrName of attr_name
type partitioning_attr_name = PartitioningAttrName of attr_name
type selection_attr_name = SelectionAttrName of attr_name
type sort_attr_name = SortAttrName of attr_name
type new_attr_name = NewAttrName of attr_name
type old_attr_name = OldAttrName of attr_name
type left_attr_name = LeftAttrName of attr_name
type right_attr_name = RightAttrName of attr_name

type sort_direction = Ascending | Descending
type sort_infos = (sort_attr_name * sort_direction) list
type schema_infos = (attr_name * base_type) list
type key_infos = attr_name list list
type tbl_attribute_infos = (attr_name * attr_name * base_type) list

(* semantic informations on operator nodes *)
type rownum_info = result_attr_name * sort_infos * partitioning_attr_name option
type rowid_info = result_attr_name
type rank_info = result_attr_name * sort_infos
type project_info = (new_attr_name * old_attr_name) list
type select_info = selection_attr_name
type pos_select_info = int * sort_infos * partitioning_attr_name option
type eqjoin_info = left_attr_name * right_attr_name
type thetajoin_info = (join_comparison * (left_attr_name * right_attr_name)) list
type lit_tbl_info = base_value list list * schema_infos
type attach_info = result_attr_name * base_value
type cast_info = result_attr_name * attr_name * base_type
type binop_info = result_attr_name * (left_attr_name * right_attr_name)
type unop_info = result_attr_name * attr_name
type fun_1to1_info = func * result_attr_name * (attr_name list)
type fun_aggr_info = aggr * unop_info * partitioning_attr_name option
type fun_aggr_count_info = result_attr_name * partitioning_attr_name option
type serialize_rel_info = attr_name * attr_name * (attr_name list)
type tbl_ref_info = tbl_name * tbl_attribute_infos * key_infos
type empty_tbl_info = schema_infos

type binary_op =
  | EqJoin of eqjoin_info 
  | SemiJoin of eqjoin_info 
  | ThetaJoin of thetajoin_info 
  | DisjunctUnion
  | Difference 
  | SerializeRel of serialize_rel_info 
  | Cross 

type unary_op =
  | RowNum of rownum_info 
  | RowID of rowid_info 
  | RowRank of rank_info 
  | Rank of rank_info 
  | Project of project_info 
  | Select of select_info 
  | PosSelect of pos_select_info 
  | Distinct
  | Attach of attach_info 
  | Cast of cast_info 
  | FunNumEq of binop_info 
  | FunNumGt of binop_info 
  | Fun1to1 of fun_1to1_info 
  | FunBoolAnd of binop_info 
  | FunBoolOr of binop_info 
  | FunBoolNot of unop_info 
  | FunAggr of fun_aggr_info 
  | FunAggrCount of fun_aggr_count_info 

type nullary_op =
  | LitTbl of lit_tbl_info
  | EmptyTbl of schema_infos
  | TblRef of tbl_ref_info
  | Nil

type node =
  | BinaryNode of binary_op * node * node
  | UnaryNode of unary_op * node
  | NullaryNode of nullary_op

module ExportBase = struct

  let string_of_sort_direction = function
    | Ascending -> "ascending"
    | Descending -> "descending"

  let string_of_join_comparison = function
    | Eq -> "="
    | Gt -> ">"
    | Ge -> ">="
    | Lt -> "<"
    | Le -> "<="
    | Ne -> "<>"

  let string_of_base_type = function
    | IntType -> "int"
    | StrType -> "str"
    | BoolType -> "bool"
    | DecType -> "dec"
    | DblType -> "dbl"
    | NatType -> "nat"

  let string_of_base_value = function
    | Int i -> string_of_int i
    | Str s -> s
    | Bool b -> string_of_bool b
    | Double d -> string_of_float d
    | Dec d -> string_of_float d
    | Nat n -> string_of_int n

  let typestring_of_base_value = function
    | Int _ -> "int"
    | Str _ -> "str"
    | Bool _ -> "bool"
    | Double _ -> "dbl"
    | Dec _ -> "dec"
    | Nat _ -> "nat"

  let string_of_func = function
    | Add -> "add"
    | Subtract -> "subtract"
    | Multiply -> "multiply"
    | Divide -> "divide"
    | Modulo -> "modulo"
    | Contains -> "fn:contains"

  let tag name = ("", name), []

  let attr_list xml_attributes = 
    List.map 
      (fun (name, value) -> ("", name), value) 
      xml_attributes

  let tag_attr name attributes = ("", name), (attr_list attributes)

  let out_el out name xml_attributes =
    out (`El_start (tag_attr name xml_attributes));
    out `El_end

  let out_el_childs out name xml_attributes child_fun =
    out (`El_start (tag_attr name xml_attributes));
    child_fun ();
    out `El_end

  let out_col out xml_attributes = out_el out "column" xml_attributes

  let out_col_childs out xml_attributes child_fun = 
    out_el_childs out "column" xml_attributes child_fun

  let out_arg_pair out argp =
    let (LeftAttrName larg, RightAttrName rarg) = argp in
      out_col out [("name", larg); ("new", "false"); ("position", "1")];
      out_col out [("name", rarg); ("new", "false"); ("position", "2")]

  let out_empty_tbl_info out schema =
    out (`El_start (tag "content"));
    List.iter
      (fun (name, typ) ->
	 out_col out [("name", name); ("type", string_of_base_type typ); ("new", "true")])
      schema;
    out `El_end

  let out_binop_info out info =
    let (ResultAttrName result_attr, arg_pair) = info in
      out (`El_start (tag "content"));
      out_col out [("name", result_attr); ("new", "true")];
      out_arg_pair out arg_pair;
      out `El_end

  let out_sort_infos out l =
    ignore 
      (List.fold_left
	 (fun i ((SortAttrName name), dir) ->
	    let xml_attributes = [
	      ("name", name);
	      ("direction", string_of_sort_direction dir);
	      ("position", string_of_int i);
	      ("new", "false")]
	    in
	      out_col out xml_attributes;
	      (i + 1))
	 0
	 l)

  let out_maybe_part_name out maybe_part_name =
    match maybe_part_name with
      | Some (PartitioningAttrName part_name) ->
	  out_col out [("name", part_name); ("function", "partition"); ("new", "false")]
      | None ->
	  ()

  let out_rownum_info out (i : rownum_info) =
    let ((ResultAttrName resname), sort_infos, maybe_part_name) = i in
      out (`El_start (tag "content"));
      out_col out [("name", resname); ("new", "true")];
      out_sort_infos out sort_infos;
      out_maybe_part_name out maybe_part_name;
      out `El_end

  let out_rowid_info out (ResultAttrName res_attr) =
    out (`El_start (tag "content"));
    out_col out [("name", res_attr)];
    out `El_end

  let out_rank_info out (((ResultAttrName resname), sort_infos) : rank_info) =
    out (`El_start (tag "content"));
    out_col out [("name", resname); ("new", "true")];
    out_sort_infos out sort_infos;
    out `El_end

  let out_project_info out (l : project_info) =
    let f ((NewAttrName new_name), (OldAttrName old_name)) = 
      if old_name = new_name then
	out_col out [("name", new_name); ("new", "false")]
      else
	out_col out [("name", new_name); ("old_name", old_name); ("new", "true")]
    in
      out (`El_start (tag "content"));
      List.iter f l;
      out `El_end

  let out_select_info out ((SelectionAttrName sel_attr) : select_info) =
    out (`El_start (tag "content"));
    out_col out [("name", sel_attr); ("new", "false")];
    out `El_end

  let out_pos out pos =
    out (`El_start (tag "position"));
    out (`Data (string_of_int pos));
    out `El_end

  let out_pos_select_info out ((pos, sort_infos, maybe_part_attr) : pos_select_info) =
    out (`El_start (tag "content"));
    out_pos out pos;
    out_sort_infos out sort_infos;
    out_maybe_part_name out maybe_part_attr;
    out `El_end

  let out_eqjoin_info out (arg_pair : eqjoin_info) =
    out (`El_start (tag "content"));
    out_arg_pair out arg_pair;
    out `El_end

  let out_thetajoin_info out (l : thetajoin_info) =
    out (`El_start (tag "content"));
    List.iter
      (fun (comp, attributes) ->
	 out (`El_start (tag_attr "comparison" [("kind", string_of_join_comparison comp)]));
	 out_arg_pair out attributes;
	 out `El_end)
      l;
    out `El_end

  let out_lit_tbl_info out ((values_per_col, schema_infos) : lit_tbl_info) =
    out (`El_start (tag "content"));
    (try 
       List.iter2
	 (fun values info ->
	    let c () =
	      List.iter 
		(fun value ->
		   out_el_childs
		     out 
		     "value" 
		     [("type", typestring_of_base_value value)]
		     (fun () -> out (`Data (string_of_base_value value))))
		values
	    in
	      out_col_childs out [("name", fst info)] c)
	 values_per_col
	 schema_infos
     with Invalid_argument _ -> 
       failwith "out_lit_tbl_info: list lengths do not match");
    out `El_end

  let out_attach_info out (ResultAttrName result_attr, value) =
    out (`El_start (tag "content"));
    let xml_attrs = [("name", result_attr); ("new", "true")] in
    let f () = out (`Data (string_of_base_value value)) in
      out_col_childs out xml_attrs f

  let out_cast_info out (ResultAttrName result_attr, name, base_type) =
    out (`El_start (tag "content"));
    out_col out [("name", result_attr); ("new", "true")];
    out_col out [("name", name); ("new", "false")];
    out_col out [("name", string_of_base_type base_type)];
    out `El_end

  let out_binop_info out (ResultAttrName result_attr, arg_pair) =
    out (`El_start (tag "content"));
    out_col out [("name", result_attr); ("new", "true")];
    out_arg_pair out arg_pair;
    out `El_end

  let out_unop_info out (ResultAttrName result_attr, arg_attr) =
    out (`El_start (tag "content"));
    out_col out [("name", result_attr); ("new", "true")];
    out_col out [("name", arg_attr); ("new", "false")];
    out `El_end

  let out_fun_1to1_info out (f, (ResultAttrName result_attr), arg_list) =
    out (`El_start (tag "content"));
    out_el out "kind" [("name", string_of_func f)];
    out_col out [("name", result_attr); ("new", "true")];
    ignore (
      List.fold_left
	(fun i arg_attr ->
	   out_col out [("name", arg_attr); ("new", "false"); ("position", string_of_int i)];
	   (i + 1))
	0
	arg_list);
    out `El_end

  (* TODO: aggr is unused. ferryc code does not conform to the wiki spec. *)
  let out_fun_aggr_info out info =
    let (_aggr, (ResultAttrName result_attr, arg_attr), maybe_part_attr) = info in
      out (`El_start (tag "content"));
      out_col out [("name", result_attr); ("new", "true")];
      out_col out [("name", arg_attr); ("new", "false"); ("function", "item")];
      out_maybe_part_name out maybe_part_attr;
      out `El_end
	
  let out_fun_aggr_count_info out (ResultAttrName result_attr, maybe_part_attr) =
    out (`El_start (tag "content"));
    out_col out [("name", result_attr)];
    out_maybe_part_name out maybe_part_attr;
    out `El_end

  let out_serialize_rel_info out (iter, pos, items) =
    out (`El_start (tag "content"));
    out_col out [("name", iter); ("new", "false"); ("function", "iter")];
    out_col out [("name", pos); ("new", "false"); ("function", "pos")];
    ignore (
      List.fold_left
	(fun i item ->
	   out_col out [("name", item); 
			("new", "false"); 
			("function", "item"); 
			("position", string_of_int i)];
	   (i + 1))
	0
	items);
    out `El_end

  let out_tbl_ref_info out (tbl_name, attr_infos, key_infos) =
    out (`El_start (tag "properties"));
    out (`El_start (tag "keys"));
    List.iter
      (fun key ->
	 let c () =
	   List.fold_left
	     (fun i attr -> 
		out_col out [("name", attr); ("position", string_of_int i)];
		(i + 1))
	     0
	     key
	 in
	   out_el_childs out "key" [] c)
      key_infos;
    out `El_end;
    out `El_end;
    out (`El_start (tag "content"));
    let c () =
      List.iter 
	(fun (external_name, internal_name, typ) ->
	   out_col out [("name", external_name); 
			("tname", internal_name); 
			("type", string_of_base_type typ)])
	attr_infos
    in
      out_el_childs out "table" [("name", tbl_name)] c;
      out `El_end


end

module type ExportSig = sig
  val export_plan : string -> node -> unit
end

module ExportTree : ExportSig = struct
  open ExportBase

  let id_a i = "id", string_of_int i
  let kind_a s = "kind", s
  let out_edge out t = out_el out "edge" [("to", string_of_int t)]

  let out_nullary_op out op id =
    match op with
      | LitTbl lit_tbl_info ->
	  let xml_attrs = [id_a id; kind_a "node"] in
	    out (`El_start (tag_attr "node" xml_attrs));
	    out_lit_tbl_info out lit_tbl_info;
	    out `El_end
      | EmptyTbl info ->
	  let xml_attrs = [id_a id; kind_a "empty_tbl"] in
	    out (`El_start (tag_attr "node" xml_attrs));
	    out_empty_tbl_info out info;
	    out `El_end
      | TblRef info ->
	  let xml_attrs = [id_a id; kind_a "ref_tbl"] in
	    out (`El_start (tag_attr "node" xml_attrs));
	    out_tbl_ref_info out info;
	    out `El_end
      | Nil ->
	  let xml_attrs = [id_a id; kind_a "nil"] in
	    out (`El_start (tag_attr "node" xml_attrs));
	    out `El_end

  let out_unary_op out op id =
    let e () = out_edge out (id + 1) in
    let n kind info_fun =
      let xml_attrs = [id_a id; kind_a kind] in
	out (`El_start (tag_attr "node" xml_attrs));
	info_fun ();
	e ();
	out `El_end
    in
      match op with
	| RowNum rownum_info ->
	    n "row_num" (fun () -> out_rownum_info out rownum_info)
	| RowID rowid_info ->
	    n "row_id" (fun () -> out_rowid_info out rowid_info)
	| RowRank rank_info ->
	    n "rowrank" (fun () -> out_rank_info out rank_info)
	| Rank rank_info ->
	    n "rank" (fun () -> out_rank_info out rank_info)
	| Project project_info ->
	    n "project" (fun () -> out_project_info out project_info)
	| Select select_info ->
	    n "select" (fun () -> out_select_info out select_info)
	| PosSelect pos_select_info ->
	    n "pos_select" (fun () -> out_pos_select_info out pos_select_info)
	| Distinct ->
	    n "distinct" (fun () -> ())
	| Attach attach_info ->
	    n "attach" (fun () -> out_attach_info out attach_info)
	| Cast cast_info ->
	    n "cast" (fun () -> out_cast_info out cast_info)
	| FunNumEq binop_info ->
	    n "eq" (fun () -> out_binop_info out binop_info)
	| FunNumGt binop_info ->
	    n "gt" (fun () -> out_binop_info out binop_info)
	| Fun1to1 fun_1to1_info ->
	    n "fun" (fun () -> out_fun_1to1_info out fun_1to1_info)
	| FunBoolAnd binop_info ->
	    n "and" (fun () -> out_binop_info out binop_info)
	| FunBoolOr binop_info ->
	    n "or" (fun () -> out_binop_info out binop_info)
	| FunBoolNot unop_info ->
	    n "not" (fun () -> out_unop_info out unop_info)
	| FunAggr fun_aggr_info ->
	    n "aggr" (fun () -> out_fun_aggr_info out fun_aggr_info)
	| FunAggrCount fun_aggr_count_info ->
	    n "count" (fun () -> out_fun_aggr_count_info out fun_aggr_count_info)

  let out_binary_op out op id right_child_id =
    let e () =
      out_edge out (id + 1);
      out_edge out right_child_id
    in
    let n kind info_fun =
      let xml_attrs = [id_a id; kind_a kind] in
	out (`El_start (tag_attr "node" xml_attrs));
	info_fun ();
	e ();
	out `El_end
    in
      match op with
	| EqJoin  eqjoin_info ->
	    n "eqjoin" (fun () -> out_eqjoin_info out eqjoin_info)
	| SemiJoin  eqjoin_info ->
	    n "semijoin" (fun () -> out_eqjoin_info out eqjoin_info)
	| ThetaJoin  thetajoin_info ->
	    n "thetajoin" (fun () -> out_thetajoin_info out thetajoin_info)
	| DisjunctUnion ->
	    n "union" (fun () -> ())
	| Difference ->
	    n "difference" (fun () -> ())
	| SerializeRel  serialize_rel_info ->
	    n "serialize relation" (fun () -> out_serialize_rel_info out serialize_rel_info)
	| Cross ->
	    n "cross" (fun () -> ())

  let rec out_node (out, node, id) =
    match node with
      | NullaryNode op ->
	  out_nullary_op out op id;
	  id
      | UnaryNode (op, child) ->
	  let max_id = out_node (out, child, (id + 1)) in
	    out_unary_op out op id;
	    max_id
      | BinaryNode (op, child1, child2) ->
	  let max_id_left = out_node (out, child1, (id + 1)) in
	  let max_id_right = out_node (out, child2, (max_id_left + 1)) in
	    out_binary_op out op id (max_id_left + 1);
	    max_id_right

  let export_plan fname tree = 
    let oc = open_out fname in
    let o = Xmlm.make_output ~nl:true ~indent:(Some 2) (`Channel oc) in
    let out = Xmlm.output o in
    let wrap arg =
      out (`Dtd None);
      out (`El_start (tag_attr "logical_query_plan" [("unique_names", "true")]));
      ignore (out_node arg);
      out `El_end
    in
      apply wrap (out, tree, 0) ~finally:close_out oc
end

let test () =
  let t = 
    BinaryNode (SerializeRel ("item0", "item0", ["item0"; "item1"]),
		NullaryNode Nil,
		NullaryNode (TblRef ("t1", [("item0", "foo", NatType); ("item1", "bar", NatType)], [["foo"; "bar"]])))
    
  in
    ExportTree.export_plan "plan.xml" t
			      