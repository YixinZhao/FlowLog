open Flowlog_Types;;
open Controller_Forwarding;;
open Xsb_Communication;;
open Flowlog_Thrift_Out;;
open Type_Helpers;;

let debug = true;;

(* Provides functions for running a Flowlog program.*)
module Evaluation = struct

	let send_notifications (bb : Types.blackbox) (out_notifs : Types.notif_val list) : unit =
		if debug then List.iter (fun out_notif -> print_endline ("outgoing notif: " ^ Type_Helpers.notif_val_to_string out_notif)) out_notifs;
		match bb with
		| Types.Internal_BB(name) -> if name = "forward" then Controller_Forwarding.forward_packets out_notifs 
                                             else raise (Failure ("internal black box " ^ name ^ " is not currently supported.")) 
		| _ -> List.iter (fun n -> if debug then Printf.printf "SENDING EXT NOTIF: %s\n%!" (Type_Helpers.notif_val_to_string n);
	                               Flowlog_Thrift_Out.doBBnotify bb n)
	                     out_notifs;;

	let fire_relation (prgm : Types.program) (rel : Types.relation) (notif : Types.notif_val)  : unit =
		if debug then print_endline ("firing relation: " ^ (Type_Helpers.relation_name rel));
		(* terms contains the terms in the INCOMING notif *val*. ntype is the type of the INCOMING val *)
		match notif with Types.Notif_val(ntype, terms) ->
		let arg_terms = List.map (fun t -> Types.Arg_term(t)) terms in
		match rel with		
		| Types.NotifRelation(bb, args, _) ->
		    (* args is the args in the head of this relation. the second one gives us our target type. *)
			(match args with
			| [] -> raise (Failure "notif relations always have two arguments.");			
			| [_; (Types.Arg_notif(Types.Notif_var(targettype, _))) as tail] -> 				    
			    let out_notifs = List.map (fun (tl : Types.term list) -> Types.Notif_val(targettype, tl))
				                          (Communication.query_relation rel (arg_terms @ [tail])) in
			      send_notifications bb out_notifs;
			| [_;_] -> raise (Failure "malformed second argument to notif relation");
			| _ -> failwith "failure of fire_relation assumption: notif_type args is 2 element list")
			  			
		| Types.MinusRelation(_, args, _) ->
			(match args with
			| [] -> raise (Failure "minus relations always have at least one argument.");
			| _ :: tail ->
			let to_retract = Communication.query_relation rel (arg_terms @ tail) in
			if debug then Printf.printf "Retracting %d facts.\n%!" (List.length to_retract);
			let helper_rel = Type_Helpers.helper_relation prgm rel in
			List.iter (fun (tl : Types.term list) -> Communication.retract_relation helper_rel tl) to_retract;);
		| Types.PlusRelation(_, args, _) ->
			(match args with
			| [] -> raise (Failure "plus relations always have at least one argument.");
			| _ :: tail ->
			(* to_assert contains the list of tuples that the query vs. +R returned. These should be added to R. *)
			let to_assert = Communication.query_relation rel (arg_terms @ tail) in
			if debug then Printf.printf "Asserting %d facts.\n%!" (List.length to_assert);
			(* The helper_rel should be R, not +R *)
			let helper_rel = Type_Helpers.helper_relation prgm rel in			
			List.iter (fun (tl : Types.term list) -> 
		                 Communication.assert_relation helper_rel tl) 
		              to_assert);
		| Types.HelperRelation(_, _, _) -> raise (Failure "helper relations cannot be fired.");;

	let debug1 = false;;

	let respond_to_notification (notif : Types.notif_val) (prgm : Types.program) : unit =
		if debug1 then print_endline ("incoming notif: " ^ Type_Helpers.notif_val_to_string notif);
		match prgm with Types.Program(name, _, _, _, clauses) ->
		match notif with Types.Notif_val(ntype, _) ->
		List.iter (function Types.Clause(ctype, name, args, body) -> match ctype with
			| Types.Action -> match args with
				| [Types.Notif_var(nt, _), Types.Notif_var(_, _)] -> if nt = ntype then queue_fire_cls cls ;
			| _ -> (););
		List.iter (function Types.Clause(ctype, name, args, body) -> match ctype with
			| Types.Minus -> ... ;
			| _ -> (););
		List.iter (function Types.Clause(ctype, name, args, body) -> match ctype with
			| Types.Plus -> ... ;
			| _ -> (););
		

		let _ = List.iter (fun rel -> match rel with
			| Types.NotifRelation(bb, args, _) -> (match args with
				| [] -> raise (Failure "NotifRelations always have two arguments");
				| Types.Arg_notif(Types.Notif_var(nt, _)) :: _ -> if debug1 then print_endline ((Type_Helpers.blackbox_name bb) ^ ": " ^ Type_Helpers.notif_type_to_string nt);
					if nt = ntype then fire_relation prgm rel notif;
				| _ -> raise (Failure "NotifRelations always have an Arg_notif as their first argument"););
			| _ -> ();) relations in
		if debug1 then print_endline "starting MinusRelations.";
		let _ = List.iter (fun rel -> match rel with
			| Types.MinusRelation(name, args, _) -> (match args with
				| [] -> raise (Failure "MinusRelations always have at least two arguments");
				| Types.Arg_notif(Types.Notif_var(nt, _)) :: _ -> if debug1 then print_endline ("-" ^ name ^ ": " ^ Type_Helpers.notif_type_to_string nt);
					if nt = ntype then fire_relation prgm rel notif;
				| _ -> raise (Failure "MinusRelations always have an Arg_notif as their first argument"););
			| _ -> ();) relations in
		if debug1 then print_endline "starting PlusRelations.";
		let _ = List.iter (fun rel -> match rel with
			| Types.PlusRelation(name, args, _) -> (match args with
				| [] -> raise (Failure "PlusRelations always have at least two arguments");
				| Types.Arg_notif(Types.Notif_var(nt, _)) :: _ -> if debug1 then print_endline ("+" ^ name ^ ": " ^ Type_Helpers.notif_type_to_string nt);
					if nt = ntype then fire_relation prgm rel notif;
				| _ -> raise (Failure "PlusRelations always have an Arg_notif as their first argument"););
			| _ -> ();) relations in ();;
	

end
