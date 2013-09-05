open Flowlog_Types
open Flowlog_Helpers
open NetCore_Types
open ExtList.List
open Printf
open Xsb_Communication
open Flowlog_Thrift_Out
open Packet


(* XSB is shared state. We also have the remember_for_forwarding and packet_queue business *)
let xsbmutex = Mutex.create();;

(* Map query formula to results and time obtained (floating pt in seconds) *)
let remote_cache = ref FmlaMap.empty;;

(* (unit->unit) option *)
(* Trigger thunk to refresh policy in stream. *)
let refresh_policy = ref None;;

(* action_atom list = atom *)
let fwd_actions = ref [];;

(* Push function for packet stream. Used to emit rather than forward. *)
(* Not sure why the input can be option. *)
let emit_push: ((NetCore_Types.switchId * NetCore_Types.portId * Packet.bytes) option -> unit) option ref = ref None;;

let guarded_refresh_policy () : unit = 
  match !refresh_policy with
    | None -> printf "Policy has not been created yet. Error!\n%!"
    | Some f -> f();;

let guarded_emit_push (swid: switchId) (pt: portId) (bytes: Packet.bytes): unit = 
  match !emit_push with
    | None -> printf "Packet stream has not been created yet. Error!\n%!"
    | Some f -> f (Some (swid,pt,bytes));;


let counter_inc_pkt = ref 0;;
let counter_inc_all = ref 0;;

(* 
  ALLOWED atomic fmlas:

  // assume in clause body. assume NNF. assume vars have been substituted out as much as possible
  // means that such vars that DO occur can never appear as x=y or x=const.
  
  
  (5) atom: 
*)

(* FORBIDDEN (pass to controller always):
% (1) joins over existentials [can do better here, no hard constraint]
% (2) assigns to newpkt fields not supported for modif. in OF, like nwProto [up to openflow to allow]
% (3) assigns to allowed newpkt field in pkt-dependent way, not state-dep way 
%    e.g. newpkt.dlSrc = pkt.dlDst
%    but R(newpkt.dlSrc, pkt.dlDst) is ok
%    ^^^ this may result in multiple packets being sent. but that's fine.
%    SPECIAL CASE: newpkt.locPt != pkt.locPt is allowed. Means to use AllPorts.
% (4) pkt.x = pkt.y --- can't do equality in netcore preds
*)

(* Any assignment to a newpkt field must either be 
  (1) the trivial old-field assignment WITHOUT a surrounding not
  (2) a positive relational binding (no surrounding NOT)      
  (3) special case NOT newpkt.locPt = oldpkt.locPt *)

exception IllegalFieldModification of formula;;
exception IllegalAssignmentViaEquals of formula;;
exception IllegalAtomMustBePositive of formula;;
exception IllegalExistentialUse of formula;;
exception IllegalModToNewpkt of (term * term);;
exception IllegalEquality of (term * term);;

exception UnsatisfiableFlag;;

let legal_field_to_modify (fname: string): bool =
	mem fname legal_to_modify_packet_fields;;

(* 2 & 3 *) 
let rec forbidden_assignment_check (newpkt: string) (f: formula) (innot: bool): unit = 
    
    let check_netcore_temp_limit_eq (t1: term) (t2: term): unit = 
      match (t1, t2) with 
      | (TField(v1, f1), TConst(cstr)) ->
        (* can't modify packet fields right now. *CAN* set the port, of course. *)
        if (v1 = newpkt) && (f1 <> "locpt") then raise (IllegalModToNewpkt(t1,t2))
      | _ -> ()
    in

 	  let check_legal_newpkt_fields = function  
							| TField(varname, fld)
                when varname = newpkt -> 
      				   			if not (legal_field_to_modify fld) then
      	 					   		raise (IllegalFieldModification f)
      	 					| _ -> () 
      	 				in
    (* use of negation on equality: ok if [pkt.x = 5], [new.pt = old.pt] *)
    let check_legal_negation (t1: term) (t2: term): unit =
      let dangerous = (match (t1, t2) with 
          | (TField(v1, f1), TField(v2, f2)) ->
            f1 <> "locpt" || f2 <> "locpt"
          | (TField(v1, f1), TConst(cstr)) -> v1 = newpkt
          | _ -> false) in 
      (*(printf "check_legal_negation: %s %s %b %b\n%!" (string_of_term t1) (string_of_term t2) innot dangerous);*)
      if (innot && dangerous) then raise (IllegalEquality(t1,t2))
    in

    let check_not_same_pkt (t1: term) (t2: term): unit =
      match (t1, t2) with 
        | (TField(v, f), TField(v2, f2)) when v = v2 && f2 <> f ->
              raise (IllegalEquality(t1,t2))
        | _ -> ()
    in


    let check_same_field_if_newpkt (t1:term) (t2:term) : unit = 
    	match (t1, t2) with
			   | (TField(var1, fld1), TField(var2, fld2))
			     	when var1 = newpkt || var2 = newpkt ->
			       	if fld1 <> fld2 then raise (IllegalAssignmentViaEquals f)
      	 | (TField(var1, fld1), TVar(_)) 
            when var1 = newpkt -> raise (IllegalAssignmentViaEquals f)
      	 | (TVar(_), TField(var1, fld2)) 
            when var1 = newpkt -> raise (IllegalAssignmentViaEquals f)
      	 | (TField(var1, fld1), TConst(_)) -> ()	
      	 | (TConst(_), TField(var2, fld2)) -> ()
      	 | _ -> ()	      	 	
      	 	in

	match f with
		| FTrue -> ()
    	| FFalse -> ()
    	| FAnd(f1, f2) ->
      		 forbidden_assignment_check newpkt f1 innot;
      		 forbidden_assignment_check newpkt f2 innot;
      	| FOr(f1, f2) -> 
      		 forbidden_assignment_check newpkt f1 innot;
      		 forbidden_assignment_check newpkt f2 innot;
      	| FNot(f) -> forbidden_assignment_check newpkt f (not innot);
    	| FEquals(t1, t2) -> 
        (* ALLOWED: 
        (1) equality: between new and old, same field. NOT negated
        (2) equality: special case NOT(newpkt.locPt = pkt.locPt)
        (3) equality: new = const
        (4) equality: old = const *)
        check_legal_negation t1 t2; (* if negated, must be special case *)
    		check_legal_newpkt_fields t1; (* not trying to set an unsettable field *)
    		check_legal_newpkt_fields t2;
    		check_same_field_if_newpkt t1 t2; (* can't swap fields, etc. w/o controller *)
        check_not_same_pkt t1 t2;
        check_netcore_temp_limit_eq t1 t2;

      	| FAtom(modname, relname, tlargs) ->       		
      		(* new field must be legal for modification by openflow *)
      		iter check_legal_newpkt_fields tlargs;
      		(* if involves a newpkt, must be positive *)    
      		if (innot && (ExtList.List.exists (function | TField(fvar, _) when fvar = newpkt -> true | _ -> false) tlargs)) then  	
      			raise (IllegalAtomMustBePositive f);;      		

(* returns list of existentials used by f. Will throw exception if re-used in new *atomic* fmla.
	assume this is a clause fmla (no disjunction) *)
let rec common_existential_check (newpkt: string) (sofar: string list) (f: formula): string list =
  (* If extending this method beyond just FORWARD clauses, remember that any var in the head
      is "safe" to cross literals. *)
	let ext_helper (t: term): (string list) =
		match t with 
			| TVar(v) -> 
				if mem v sofar then raise (IllegalExistentialUse f)
				else [v]
			| TConst(_) -> []
			(* | TField(,_) -> [] *)
      (* netcore limitation in recent version, going away soon *)
      | TField(fvar,ffld) -> 
          if fvar = newpkt && ffld <> "locpt" then 
            raise (IllegalModToNewpkt(t, t))
          else [] 
		in

	match f with
		| FTrue -> []
   	| FFalse -> []
   	| FAnd(f1, f2) ->
     		 let lhs_uses = common_existential_check newpkt sofar f1 in
     		 	(* unique is in ExtLst.List --- removes duplicates *)
     		 	unique (lhs_uses @ common_existential_check newpkt (lhs_uses @ sofar) f2)
  	| FOr(f1, f2) -> failwith "common_existential_check"      		 
  	| FNot(f) -> common_existential_check newpkt sofar f 
   	| FEquals(t1, t2) -> 
   		(* equals formulas don't represent a join. do nothing *)
   		sofar
   	| FAtom(modname, relname, tlargs) ->  
    		unique (flatten (map ext_helper tlargs));;	

let validate_fwd_clause (cl: clause): unit =
  printf "Validating clause: %s\n%!" (string_of_clause cl);
	match cl.head with 
		| FAtom("", "forward", [TVar(newpktname)]) ->
      ignore (common_existential_check newpktname [] cl.body);  
			forbidden_assignment_check newpktname cl.body false;    
      printf "Forward clause was valid.\n%!";
		| _ -> failwith "validate_clause";;

(***************************************************************************************)

let rec get_state_maybe_remote (p: flowlog_program) (f: formula): (string list) list =
  match f with 
    | FAtom(modname, relname, args) when (is_remote_table p relname) ->
      (* Is this query still in the cache? Then just use it. *)
      if FmlaMap.mem f !remote_cache then
      begin
        let (cached_results, _) = FmlaMap.find f !remote_cache in
          cached_results
      end
      (* Otherwise, need to call out to the blackbox. *)
      else
      begin
        match get_remote_table p relname with
          | (ReactRemote(relname, qryname, ip, port, refresh), DeclRemoteTable(drel, dargs)) ->            
            (* qryname, not relname, when querying *)
            printf "REMOTE STATE --- REFRESHING: %s\n%!" (string_of_formula f);
            let bb_results = Flowlog_Thrift_Out.doBBquery qryname ip port args in
              remote_cache := FmlaMap.add f (bb_results, Unix.time()) !remote_cache;
              iter Communication.assert_formula 
                (map (reassemble_xsb_atom modname relname) bb_results);
              bb_results 

          | _ -> failwith "get_state_maybe_remote"
      end
    | FAtom(modname, relname, args) ->          
        Communication.get_state f
    | _ -> failwith "get_state_maybe_remote";;

(* get_state_maybe_remote calls out to BB and updates the cache IF UNCACHED. *)
let pre_load_all_remote_queries (p: flowlog_program): unit =
  let remote_fmlas = 
    filter (function | FAtom(modname, relname, args) when (is_remote_table p relname) -> true
                     | _-> false)
           (get_atoms_used_in_bodies p) in
    iter (fun f -> ignore (get_state_maybe_remote p f)) remote_fmlas;;    


(* Replace state references with constant matrices *)
let rec partial_evaluation (p: flowlog_program) (incpkt: string) (f: formula): formula = 
  (* assume valid clause body for PE *)
  match f with 
    | FTrue -> f
    | FFalse -> f
    | FEquals(t1, t2) -> f
    | FAnd(f1, f2) -> FAnd(partial_evaluation p incpkt f1, partial_evaluation p incpkt f2)
    | FNot(innerf) -> 
        let peresult = partial_evaluation p incpkt innerf in
        (match peresult with | FTrue -> FFalse | FFalse -> FTrue | _ -> FNot(peresult))
    | FOr(f1, f2) -> failwith "partial_evaluation: OR"              
    | FAtom(modname, relname, tlargs) ->  
      printf ">> partial_evaluation on atomic %s\n%!" (string_of_formula f);
      Mutex.lock xsbmutex;
      let xsbresults: (string list) list = get_state_maybe_remote p f in
        Mutex.unlock xsbmutex;        
        let disjuncts = map 
          (fun sl -> build_and (reassemble_xsb_equality incpkt tlargs sl)) 
          xsbresults in
        let fresult = build_or disjuncts in
        printf "<< partial evaluation result (converted from xsb) was: %s\n%!" (string_of_formula fresult);        
        fresult;;

(***************************************************************************************)

let rec build_switch_actions (oldpkt: string) (body: formula): action =
  let create_port_actions (actlist: action) (lit: formula): action =
    match lit with 
    | FFalse -> raise UnsatisfiableFlag
    | FTrue -> actlist
    | FNot(FEquals(TField(var1, fld1), TField(var2, fld2))) -> 
      if var1 = oldpkt && fld1 = "locpt" && fld2 = "locpt" then         
        [SwitchAction({id with outPort = NetCore_Pattern.All})] @ actlist 
      else if var2 = oldpkt && fld2 = "locpt" && fld1 = "locpt" then 
        [SwitchAction({id with outPort = NetCore_Pattern.All})] @ actlist 
      else failwith ("create_port_actions: bad negation: "^(string_of_formula body))

    | FEquals(TField(var1, fld1), TField(var2, fld2)) ->
      if fld1 <> fld2 then 
        failwith ("create_port_actions: invalid fields: "^fld1^" "^fld2)
      else 
        actlist
    
    | FEquals(TField(avar, afld), TConst(aval)) 
    | FEquals(TConst(aval), TField(avar, afld)) -> 
      if afld = "locpt" then         
        [SwitchAction({id with outPort = NetCore_Pattern.Physical(Int32.of_string aval)})] @ actlist 
      else       
        actlist

      (* remember: only called for FORWARD/EMIT rules. so safe to do this: *)
    | FNot(FEquals(TField(avar, afld), TConst(aval)))
    | FNot(FEquals(TConst(aval), TField(avar, afld))) -> 
        actlist


    | _ -> failwith ("create_port_actions: bad lit: "^(string_of_formula lit)) in

(*
  TODO: 
  outDlVlan : dlVlan match_modify;
  outDlVlanPcp : dlVlanPcp match_modify;  
}*)


  (* TODO: Netcore will support this soon (8/31) *)
  (*let enhance_action_atom (afld: string) (aval: string) (anact: action_atom): action_atom =
  match anact with
    SwitchAction(oldout) ->
      match afld with 
        | "locpt" -> SwitchAction({oldout with outPort = NetCore_Pattern.Physical(Int32.of_string aval)})
        | "dlsrc" -> SwitchAction({oldout with outDlSrc = (Int64.of_string aval) })
        | "dldst" -> SwitchAction({oldout with outDlDst = (Int64.of_string aval) })
        | "dltyp" -> SwitchAction({oldout with outDlTyp = (int_of_string aval) })
        | "nwsrc" -> SwitchAction({oldout with outNwSrc = (Int32.of_string aval) })
        | "nwdst" -> SwitchAction({oldout with outNwDst = (Int32.of_string aval) })
        | "nwproto" -> SwitchAction({oldout with outNwProto = (int_of_string aval) })
        | _ -> failwith ("enhance_action_atom: "^afld^" -> "^aval) in

  let create_mod_actions (actlist: action) (lit: formula): action =
    match lit with 
    | FFalse -> actlist
    | FTrue -> failwith "create_mod_actions: passed true"
    | FNot(_) -> 
      failwith ("create_mod_actions: bad negation: "^(string_of_formula body))
    | FEquals(TField(var1, fld1), TField(var2, fld2)) ->
      failwith ("create_mod_actions: invalid equality "^(string_of_formula body))

    | FEquals(TField(avar, afld), TConst(aval)) 
    | FEquals(TConst(aval), TField(avar, afld)) -> 
      if avar <> oldpkt then         
        (* since this is a FORWARD, must be over whatever we named newpkt *)
        map (enhance_action_atom afld aval) actlist
      else       
        actlist (* ignore involving newpkt *)

    | _ -> failwith ("create_mod_actions: "^(string_of_formula body)) in  
*)

  (* list of SwitchAction(output)*)
  (* - this is only called for FORWARDING rules. so only newpkt should be involved *)
  (* - assume: no negated equalities except the special case pkt.locpt != newpkt.locpt *)  
  let atoms = conj_to_list body in
   (* printf "  >> build_switch_actions: %s\n%!" (String.concat " ; " (map (string_of_formula ~verbose:true) atoms));*)
    (* if any actions are false, folding is invalidated *)
    try
      let port_actions = fold_left create_port_actions [] atoms in
      let complete_actions = port_actions in (*fold_left create_mod_actions port_actions atoms in*)      
      complete_actions
    with UnsatisfiableFlag -> [];;

open NetCore_Pattern
open NetCore_Wildcard


(* worst ocaml error ever: used "val" for varname. *)

let build_switch_pred (oldpkt: string) (body: formula): pred =  
let field_to_pattern (fld: string) (aval:string): NetCore_Pattern.t =         
  match fld with (* switch handled via different pred type *)
    | "locpt" -> {all with ptrnInPort = WildcardExact (Physical(Int32.of_string aval)) }
    | "dlsrc" -> {all with ptrnDlSrc = WildcardExact (Int64.of_string aval) }
    | "dldst" -> {all with ptrnDlDst = WildcardExact (Int64.of_string aval) }
    | "dltyp" -> {all with ptrnDlTyp = WildcardExact (int_of_string aval) }
    | "nwsrc" -> {all with ptrnNwSrc = WildcardExact (Int32.of_string aval) }
    | "nwdst" ->  {all with ptrnNwDst = WildcardExact (Int32.of_string aval) }
    | "nwproto" -> {all with ptrnNwProto = WildcardExact (int_of_string aval) }
    | _ -> failwith ("field_to_pattern: "^fld^" -> "^aval) in
    (* TODO: dlVLan, dlVLanPCP *)

  let rec eq_to_pred (eqf: formula): pred option =
    match eqf with
      | FNot(atom) -> 
        (match eq_to_pred atom with
        | None -> None
        | Some(p) -> 
          if p = Everything then Some Nothing
          else if p = Nothing then Some Everything
          else Some(Not(p)))

      (* only match oldpkt.<field> here*)        
      | FEquals(TConst(aval), TField(varname, fld)) when varname = oldpkt ->
        if fld = "locsw" then Some(OnSwitch(Int64.of_string aval))  
        else Some(Hdr(field_to_pattern fld aval))
      | FEquals(TField(varname, fld),TConst(aval)) when varname = oldpkt ->
        if fld = "locsw" then Some(OnSwitch(Int64.of_string aval))  
        else Some(Hdr(field_to_pattern fld aval))

      | FTrue -> Some(Everything)
      | FFalse -> Some(Nothing)      
      | _ -> None (* something for action, not pred *) in
      (*| _  -> failwith ("build_switch_pred: "^(string_of_formula ~verbose:true eqf)) in*)

  (* After PE, should be only equalities and negated equalities. Should be just a conjunction *)
  let eqlist = conj_to_list body in 
    let predlist = filter_map eq_to_pred eqlist in
      fold_left (fun acc pred -> match pred with 
              | Nothing -> Nothing
              | Everything -> acc
              | _ when acc = Everything -> pred 
              | _ -> And(acc, pred)) Everything predlist;; 

(* todo: lots of code overlap in these functions. should unify *)
(* removes the packet_in atom (since that's meaningless here). 
   returns the var the old packet was bound to, and the trimmed fmla *)
let rec trim_packet_from_body (body: formula): (string * formula) =
  match body with
    | FTrue -> ("", body)
    | FFalse -> ("", body)
    | FEquals(t1, t2) -> ("", body)
    | FAnd(f1, f2) -> 
      let (var1, trimmed1) = trim_packet_from_body f1 in
      let (var2, trimmed2) = trim_packet_from_body f2 in
      let trimmed = if trimmed1 = FTrue then 
                      trimmed2 
                    else if trimmed2 = FTrue then
                      trimmed1 
                    else
                      FAnd(trimmed1, trimmed2) in
      if (var1 = var2) || var1 = "" then
        (var2, trimmed)
      else if var2 = "" then
        (var1, trimmed)
      else failwith ("trim_packet_from_clause: multiple variables used in packet_in: "^var1^" and "^var2)
    | FNot(f) ->
      let (v, t) = trim_packet_from_body f in
        (v, FNot(t))
    | FOr(f1, f2) -> failwith "trim_packet_from_clause"              
    | FAtom("", relname, [TVar(varstr)]) when relname = packet_in_relname ->  
      (varstr, FTrue)
    | _ -> ("", body);;    


let policy_of_conjunction (oldpkt: string) (callback: get_packet_handler option) (body: formula): pol = 
  (* can't just say "if action is fwd, it's a fwd clause" because 
     this may be an approximation to an un-compilable clause, which needs
     interpretation at the controller! Instead trust callback to carry that info. *)  
      
  let my_action_list = match callback with
            | Some(f) -> [ControllerAction(f)]            
            | _ -> build_switch_actions oldpkt body in 

  let mypred = build_switch_pred oldpkt body in 

  Seq(Filter(mypred), Action(my_action_list));;
(*    ITE(mypred,
        Action(my_action_list), 
        Action([]));;*)
  	
(***************************************************************************************)

(* Used to pre-filter controller notifications as much as possible *)
let rec strip_to_valid (oldpkt: string) (cl: clause): clause =
  (* for now, naive solution: remove offensive literals outright. easy to prove correctness 
    of goal: result is a fmla that is implied by the real body. *)
    (* acc contains formula built so far, plus the variables seen *)
    let safeargs = (match cl.head with | FAtom(_, _, args) -> args | _ -> failwith "strip_to_valid") in
      printf "   --- ENFORCING VALIDITY: Removing literals as needed from clause body: %s\n%!" (string_of_formula cl.body);
      let may_strip_literal (acc: formula * term list) (lit: formula): (formula * term list) = 
        let (fmlasofar, seen) = acc in         

        let not_is_oldpkt_field (atomarg: term): bool = 
          match atomarg with
            | TField(fvar, ffld) when oldpkt = fvar -> false
            | _ -> true in

        match lit with 
        | FTrue -> acc
        | FFalse -> (FFalse, seen)
        | FNot(FTrue) -> (FFalse, seen)
        | FNot(FFalse) -> acc

        (* pkt.x = pkt.y  <--- can't be done in OF 1.0. just remove. *)
        | FEquals(TField(v, f), TField(v2, f2)) when v = v2 && f2 <> f -> 
          begin printf "Removing atom: %s\n%!" (string_of_formula lit); acc end
        | FNot(FEquals(TField(v, f), TField(v2, f2))) when v = v2 && f2 <> f -> 
          begin printf "Removing atom: %s\n%!" (string_of_formula lit); acc end            

        (* If this atom involves an already-seen variable not in tlargs, remove it *)
        | FAtom (_, _, atomargs)  
        | FNot(FAtom (_, _, atomargs)) ->
          if length (list_intersection (subtract (filter not_is_oldpkt_field atomargs) safeargs) seen) > 0 then 
          begin
            (* removing this atom, so a fresh term shouldnt be remembered *)
            printf "Removing atom: %s\n%!" (string_of_formula lit);
            acc
          end 
          else if fmlasofar = FTrue then
             (lit, (unique (seen @ atomargs)))
          else 
            (FAnd(fmlasofar, lit), (unique (seen @ atomargs))) 

        | FOr(_, _) -> failwith "may_strip_literal: unsupported disjunction"

        (* everything else, just build the conjunction *)        
        | _ -> 
          if fmlasofar = FTrue then (lit, seen)
          else (FAnd(fmlasofar, lit), seen)
        in 

      let literals = conj_to_list cl.body in
        match literals with 
        | [] -> cl
        | _ ->
          let (final_formula, seen) = fold_left may_strip_literal (FTrue, []) literals in
          printf "   --- Final body was:%s\n%!" (string_of_formula final_formula);
          {head = cl.head; orig_rule = cl.orig_rule; body = final_formula};;

(* Side effect: reads current state in XSB *)
(* Throws exception rather than using option type: more granular error result *)
let pkt_triggered_clause_to_netcore (p: flowlog_program) (callback: get_packet_handler option) (cl: clause): pol =   
    (match callback with 
      | None -> printf "\n--- Packet triggered clause to netcore (FULL COMPILE) on: \n%s\n%!" (string_of_clause cl)
      | Some(c) -> printf "\n--- Packet triggered clause to netcore (~CONTROLLER~) on: \n%s\n%!" (string_of_clause cl));

    match cl.head with 
      | FAtom(_, _, headargs) ->
        let (oldpkt, trimmedbody) = trim_packet_from_body cl.body in 
        printf "Trimmed packet from body: (%s, %s)\n%!" oldpkt (string_of_formula trimmedbody);

        (* Get a new fmla that is implied by the original, and can be compiled to a pred *)
        let safebody = (match callback with
          | Some(f) -> (strip_to_valid oldpkt {head = cl.head; orig_rule = cl.orig_rule; body = trimmedbody}).body
          | None ->    trimmedbody) in

        (* Do partial evaluation. Need to know which terms are of the incoming packet.
          All others can be factored out. *)
        let pebody = partial_evaluation p oldpkt safebody in
                
        (* partial eval may insert disjunctions because of multiple tuples to match 
           so we need to pull those disjunctions up and create multiple policies 
           since there may be encircling negation, also need to call nnf *)
        (* todo: this is pretty inefficient for large numbers of tuples. do better? *)
        let bodies = disj_to_list (disj_to_top (nnf pebody)) in 
        (*printf "bodies after nnf/disj_to_top = %s\n%!" (String.concat " || " (map string_of_formula bodies));*)
        (* anything not the old packet is a RESULT variable.
           Remember that we know this clause is packet-triggered, but
           we have no constraints on what gets produced. Maybe a bunch of 
           non-packet variables e.g. +R(x, y, z) ... *)
        let result = fold_left (fun acc body -> 
                         (Union (acc, policy_of_conjunction oldpkt callback body)))
                      (policy_of_conjunction oldpkt callback (hd bodies))
                      (tl bodies) in 
          printf "--- Result policy: %s\n%!" (NetCore_Pretty.string_of_pol result);          
          printf "---------------------\n\n%!";          
          result
      | _ -> failwith "pkt_triggered_clause_to_netcore";;

(* Our compilation generates a lot of duplicates sometimes. Remove them. *)
(* Issue: since callback refs are included in policies, can't compare them with = *)
let simplify_netcore_policy (p: pol): pol =
  let safe_contains_action (acts: action) (act: action_atom) =
    exists (fun actb -> match (act, actb) with 
        | (SwitchAction(_), SwitchAction(_)) -> act = actb
          (* VITAL ASSUMPTION: only one callback used here *)
        | (ControllerAction(_), ControllerAction(_)) -> true
          (* Same assumption --- separate switch event callback *)
        | _ -> false) acts in

  let safe_compare_pols (p1: pol) (p2: pol): bool =
    match (p1, p2) with
    | (Seq(Filter(pred1), Action(acts1)), Seq(Filter(pred2), Action(acts2))) ->
        pred1 = pred2 
        &&
        for_all (fun actatom2 -> safe_contains_action acts1 actatom2) acts2
        &&
        for_all (fun actatom1 -> safe_contains_action acts2 actatom1) acts1
    | _ -> failwith ("simplify_netcore_policy:safe_compare_pols "^(NetCore_Pretty.string_of_pol p1)^", "^(NetCore_Pretty.string_of_pol p1)) in

  let rec unique_list_of_pred_and (pr: pred): pred list = 
    match pr with 
      | And(pr1, pr2) -> unique (unique_list_of_pred_and pr1 @ unique_list_of_pred_and pr2)
      | _ -> [pr] in

      (* TODO: efficiency: better to simplify in PE formulas, before creating all
         these superfluous policies. *)
  let remove_contradictions (subpreds: pred list): pred list = 
    (* Hdr(...), OnSwitch(...) If contradictions, this becomes Nothing*)
    let process_pred = fun acc p -> let (sws, hdrs) = acc in match p with 
      | OnSwitch(_) as newsw -> 
        (* TODO: code duplication between pos and neg switch case *)
        if exists (fun asw -> asw <> newsw) sws then raise UnsatisfiableFlag
        else (newsw :: sws, hdrs)  
      | Not(OnSwitch(_)) as newsw ->
        if exists (fun asw -> asw <> newsw) sws then raise UnsatisfiableFlag
        else (newsw :: sws, hdrs)
         
      | Hdr(_) as newhdr -> 
        if exists (fun ahdr -> ahdr = Not(newhdr)) hdrs then raise UnsatisfiableFlag
        else (sws, newhdr :: hdrs)    
      | Not(Hdr(_) as newhdrneg) as newnot -> 
        if exists (fun ahdr -> ahdr = newhdrneg) hdrs then raise UnsatisfiableFlag
        else (sws, newnot :: hdrs)          

      | Everything -> acc
      | Nothing -> raise UnsatisfiableFlag
      | _ -> failwith ("remove_contradiction: expected only atomic preds") in
      try 
        let _ = fold_left process_pred ([],[]) subpreds in 
          subpreds
      with UnsatisfiableFlag -> [Nothing]
  in

        (* | (HandleSwitchEvent(_), HandleSwitchEvent(_)) -> true*)

  let simplify_netcore_predicate (pr: pred): pred =
    let subpreds = remove_contradictions (unique_list_of_pred_and pr) in       
      fold_left (fun acc apred -> match apred with         
          | Nothing -> Nothing 
          | Everything -> acc
          | _ when acc = Everything -> apred
          | _ when acc = Nothing -> Nothing
          | _ -> And(acc, apred)) Everything subpreds in 

  let simplify_netcore_actions (acts: action): action =
    (* if contains "all", remove every physicalport output. *)
    let is_allports_action = (fun act -> act = SwitchAction({id with outPort = NetCore_Pattern.All})) in
    let newacts = 
      if exists is_allports_action acts then 
        begin
          (* TODO Check: what happens with packet mod in actions? _should_ be split out ok.*)
          (*printf "all action found. removing single-port actions (if any).\n%!";*)
          filter is_allports_action acts          
        end
      else acts in
    

    newacts in

  let rec unique_conj_of_union (p: pol): pol list = 
    match p with 
      | Union(p1, p2) -> unique ~cmp:safe_compare_pols (unique_conj_of_union p1 @ unique_conj_of_union p2)
      | Seq(Filter(pr), Action(acts)) ->
        [Seq(Filter(simplify_netcore_predicate pr), Action(simplify_netcore_actions acts))]
      | _ -> [p] in

  let has_something_filter (p: pol): bool = 
    match p with 
      | Seq(Filter(pr), Action(acts)) -> pr <> Nothing
      | _ -> true in

  let plst = (filter has_something_filter (unique_conj_of_union p)) in  
    (* This is where nothing -> drop comes from *)
    if length plst < 1 then Seq(Filter(Nothing), Action([])) 
    else fold_left (fun acc p -> Union(acc, p)) (hd plst) (tl plst);;

(* return the union of policies for each clause *)
(* Side effect: reads current state in XSB *)
let pkt_triggered_clauses_to_netcore (p: flowlog_program) (clauses: clause list) (callback: get_packet_handler option): pol =
  let clause_pols = map (pkt_triggered_clause_to_netcore p callback) clauses in
    if length clause_pols = 0 then 
      Filter(Nothing)
    else 
      let thepol = fold_left (fun acc pol -> Union(acc, pol)) 
                (hd clause_pols) (tl clause_pols) in
        simplify_netcore_policy thepol;;

let debug = true;;

let can_compile_clause_to_fwd (cl: clause): bool =  
  try 
    if is_forward_clause cl then 
    begin
        validate_fwd_clause cl;
        true
    end
    else
      false
  with (* catch only "expected" exceptions *)
    | IllegalFieldModification(_) -> if debug then printf "IllegalFieldModification\n%!"; false
    | IllegalAssignmentViaEquals(_) -> if debug then printf "IllegalAssignmentViaEquals\n%!"; false
    | IllegalAtomMustBePositive(_) -> if debug then printf "IllegalAtomMustBePositive\n%!"; false
    | IllegalExistentialUse(_) -> if debug then printf "IllegalExistentialUse\n%!"; false
    | IllegalModToNewpkt(_, _) -> if debug then printf "IllegalModToNewpkt\n%!"; false
    | IllegalEquality(_,_) -> if debug then printf "IllegalEquality\n%!"; false;;

(* Side effect: reads current state in XSB *)
(* Set up policies for all packet-triggered clauses *)
let program_to_netcore (p: flowlog_program) (callback: get_packet_handler): (pol * pol) =
  printf "\n\n---------------------------------\nCompiling as able...\n%!";  
    (pkt_triggered_clauses_to_netcore p 
      p.can_fully_compile_to_fwd_clauses 
      None,
     pkt_triggered_clauses_to_netcore p 
     (subtract p.clauses p.can_fully_compile_to_fwd_clauses)
     (Some callback));;

let pkt_to_event (sw : switchId) (pt: port) (pkt : Packet.packet) : event =       
   let isIp = ((Packet.dlTyp pkt) = 0x0800) in
   let isArp = ((Packet.dlTyp pkt) = 0x0806) in
   let values = [
    ("locsw", Int64.to_string sw);
    ("locpt", NetCore_Pretty.string_of_port pt);
    ("dlsrc", Int64.to_string pkt.Packet.dlSrc);
    ("dldst", Int64.to_string pkt.Packet.dlDst);
    ("dltyp", string_of_int (Packet.dlTyp pkt));
    (* nwSrc/nwDst will throw an exception if you call them on an unsuitable packet *)
    ("nwsrc", if (isIp || isArp) then Int32.to_string (Packet.nwSrc pkt) else "0");
    ("nwdst", if (isIp || isArp) then Int32.to_string (Packet.nwDst pkt) else "0");
    ("nwproto", if isIp then (string_of_int (Packet.nwProto pkt)) else "arp")
    ] in
    (*let _ = if debug then print_endline ("pkt to term list: " ^ (Type_Helpers.list_to_string Type_Helpers.term_to_string ans)) in
    let _ = if debug then print_endline ("dlTyp: " ^ (string_of_int (dlTyp pkt_payload))) in*)    
    {typeid="packet"; values=construct_map values};;

(* TODO: ugly func, should be cleaned up.*)
(* augment <ev_so_far> with assignment <assn>, using tuple <tup> for values *)
let event_with_assn (p: flowlog_program) (arglist: string list) (tup: string list) (ev_so_far : event) (assn: assignment): event =
  (* for this assignment, plug in the appropriate value in tup *)
  (*printf "event_with_assn %s %s %s %s\n%!" (String.concat ";" tup) (string_of_event ev_so_far) assn.afield assn.atupvar;*)
  (*let fieldnames = (get_fields_for_type p ev_so_far.typeid) in  *)  
  (* fieldnames is fields of *event*. don't use that here. 
     e.g. 'time=t' will error, expecting time, not t.*)
  try    
    let (index, _) = (findi (fun idx ele -> ele = assn.atupvar) arglist) in  
    let const = (nth tup index) in 
      {ev_so_far with values=(StringMap.add assn.afield const ev_so_far.values)}
  with Not_found -> 
    begin
      printf "Error assigning event field <%s> from variable <%s>: did not find that variable.\n%!" assn.afield assn.atupvar;
      exit(102)
    end;;

let forward_packet (ev: event): unit =
  printf "forwarding: %s\n%!" (string_of_event ev);
  write_log (sprintf ">>> forwarding: %s\n%!" (string_of_event ev));
  (* TODO use allpackets here. compilation uses it, but XSB returns every port individually. *)
  printf "WARNING: field modifications not yet supported in netcore.\n%!";  
  fwd_actions := 
    SwitchAction({id with outPort = Physical(Int32.of_string (get_field ev "locpt"))}) 
    :: !fwd_actions;;

let emit_packet (ev: event): unit =  
  printf "emitting: %s\n%!" (string_of_event ev);
  write_log (sprintf ">>> emitting: %s\n%!" (string_of_event ev));
  let swid = (Int64.of_string (get_field ev "locsw")) in
  let pt = (Int32.of_string (get_field ev "locpt")) in
  let dlSrc = Int64.of_string (get_field ev "dlsrc") in 
  let dlDst = Int64.of_string (get_field ev "dldst") in 
  let dlTyp = int_of_string (get_field ev "dltyp") in   
    
  (* todo: higher-layer stuff if the dltyp matches. ip or arp *)
  (*let nwSrc = Int64.of_string (get_field notif "NWSRC") in 
  let nwDst = Int64.of_string (get_field notif "NWDST") in 
  let nwProto = Int64.of_string (get_field notif "NWPROTO") in *)
        
  let pktbytes = Packet.marshal(
          {Packet.dlSrc = dlSrc; Packet.dlDst = dlDst;
           Packet.dlVlan = None; Packet.dlVlanPcp = 0;
           nw = Packet.Unparsable(dlTyp, Cstruct.create(0))
          }) in
    guarded_emit_push swid pt pktbytes;;

let send_event (ev: event) (ip: string) (pt: string): unit =
  printf ">>> sending: %s\n%!" (string_of_event ev);  
  write_log (sprintf "sending: %s\n%!" (string_of_event ev));
  doBBnotify ev ip pt;;

let execute_output (p: flowlog_program) (defn: sreactive): unit =  
  match defn with 
    | ReactOut(relname, argstrlist, outtype, assigns, spec) ->
     
      let execute_tuple (tup: string list): unit =
        printf "EXECUTING OUTPUT... tuple: %s\n%!" (String.concat ";" tup);
        (* arglist orders the xsb results. assigns says how to use them, spec how to send them. *)
        let initev = (match spec with 
                  | OutForward | OutEmit -> {typeid = "packet"; values=StringMap.empty}      
                  | OutLoopback -> failwith "loopback unsupported currently"
                  | OutSend(ip, pt) -> {typeid=outtype; values=StringMap.empty}) in                
        let ev = fold_left (event_with_assn p argstrlist tup) initev assigns in          
          match spec with 
            | OutForward -> forward_packet  ev
            | OutEmit -> emit_packet ev
            | OutLoopback -> failwith "loopback unsupported currently"
            | OutSend(ip, pt) -> send_event ev ip pt in

      (* query xsb for this output relation *)  
      let xsb_results = Communication.get_state (FAtom("", relname, map (fun s -> TVar(s)) argstrlist)) in        
        (* execute the results *)
        iter execute_tuple xsb_results 
    | _ -> failwith "execute_output";;

(* XSB query on plus or minus for table *)
let change_table_how (p: flowlog_program) (toadd: bool) (tbldecl: sdecl): formula list =
  match tbldecl with
    | DeclTable(relname, argtypes) -> 
      let modrelname = if toadd then (plus_prefix^"_"^relname) else (minus_prefix^"_"^relname) in
      let varlist = init (length argtypes) (fun i -> TVar("X"^string_of_int i)) in
      let xsb_results = Communication.get_state (FAtom("", modrelname, varlist)) in
      map (fun strtup -> FAtom("", relname, map (fun sval -> TConst(sval)) strtup)) xsb_results
    | _ -> failwith "change_table_how";;

let expire_remote_state_in_xsb (p: flowlog_program) : unit =

  (* The cache is keyed by rel/tuple. So R(X, 1) is a DIFFERENT entry from R(1, X). *)
  let expire_remote_if_time (p:flowlog_program) (keyfmla: formula) (values: ((string list) list * float)): unit =  
    printf "expire_remote_if_time %s\n%!" (string_of_formula keyfmla);
    let (xsb_results, timestamp) = values in   
    match keyfmla with
      | FAtom(modname, relname, args) -> 
      begin
      match get_remote_table p relname with
        | (ReactRemote(relname, qryname, ip, port, refresh), DeclRemoteTable(drel, dargs)) ->
          begin
            match refresh with 
              | RefreshTimeout(num, units) when units = "seconds" -> 
                (* expire every num units. TODO: suppt more than seconds *)
                if Unix.time() > ((float_of_int num) +. timestamp) then begin
                  printf "REMOTE STATE --- Expiring remote for formula (duration expired): %s\n%!" 
                        (string_of_formula keyfmla);
                  remote_cache := FmlaMap.remove keyfmla !remote_cache;
                  iter (fun tup -> Communication.retract_formula (reassemble_xsb_atom modname drel tup)) xsb_results
                end else 
                  printf "REMOTE STATE --- Allowing relation to remain: %s %s %s\n%!" 
                    (string_of_formula keyfmla) (string_of_int num) (string_of_float timestamp);
                  ();
              | RefreshPure -> 
                (* never expire pure tables *) 
                (); 
              | RefreshEvery -> 
                (* expire everything under this table, every evaluation cycle *)
                printf "REMOTE STATE --- Expiring remote for formula: %s\n%!" (string_of_formula keyfmla);
                remote_cache := FmlaMap.remove keyfmla !remote_cache;
                iter (fun tup -> Communication.retract_formula (reassemble_xsb_atom modname drel tup)) xsb_results;
              | RefreshTimeout(_,_) -> failwith "expire_remote_state_in_xsb: bad timeout" 
          end
        | _ -> failwith "expire_remote_state_in_xsb: bad defn_decl" 
      end
      | _ -> failwith "expire_remote_state_in_xsb: bad key formula" in 

    FmlaMap.iter (expire_remote_if_time p) !remote_cache;;

(* separate to own module once works for sw/pt *)
let respond_to_notification (p: flowlog_program) (notif: event): unit =
  try
      Mutex.lock xsbmutex;
      counter_inc_all := !counter_inc_all + 1;

      write_log (sprintf "<<< incoming: %s" (string_of_event notif));

  printf "~~~~ RESPONDING TO NOTIFICATION ABOVE ~~~~~~~~~~~~~~~~~~~\n%!";

  (* populate the EDB with event *) 
    Communication.assert_event p notif;

    (* Expire remote state if needed*)
    expire_remote_state_in_xsb p;    

    (* Since we can't hook XSB's access to these relations,
       over-generalize and ask for all the fmlas that can possibly be needed.
       For instance, if foo(X, pkt.dlSrc) is used, ask for foo(X,Y) *)
    pre_load_all_remote_queries p;

    (* for all declared outgoing events ...*)
    let outgoing_defns = get_output_defns p in
      iter (execute_output p) outgoing_defns;

    (* for all declared tables +/- *)
    let table_decls = get_local_tables p in
    let to_assert = flatten (map (change_table_how p true) table_decls) in
    let to_retract = flatten (map (change_table_how p false) table_decls) in
    printf "  *** WILL ADD: %s\n%!" (String.concat " ; " (map string_of_formula to_assert));
    printf "  *** WILL DELETE: %s\n%!" (String.concat " ; " (map string_of_formula to_retract));
    (* update state as dictated by +/-
      Semantics demand that retraction happens before assertion here! *)
    iter Communication.retract_formula to_retract;
    iter Communication.assert_formula to_assert;
    

    Xsb.debug_print_listings();    

    (* depopulate event EDB *)
    Communication.retract_event p notif;  

    Mutex.unlock xsbmutex;  
    printf "~~~~~~~~~~~~~~~~~~~FINISHED EVENT (%d total, %d packets) ~~~~~~~~~~~~~~~\n%!"
          !counter_inc_all !counter_inc_pkt;
  with
   | Not_found -> Mutex.unlock xsbmutex; printf "Nothing to do for this event.\n%!";
   | exn -> 
      begin  
      Format.printf "Unexpected exception on event: %s\n----------\n%s\n%!"
        (Printexc.to_string exn)
        (Printexc.get_backtrace ());  
        Xsb.halt_xsb();    
        exit(101);
      end;;

(* If notables is true, send everything to controller *)
let make_policy_stream (p: flowlog_program) (notables: bool) =  
  (* stream of policies, with function to push new policies on *)
  let (policies, push) = Lwt_stream.create () in

    let rec switch_event_handler (swev: switchEvent): unit =
      match swev with
      | SwitchUp(sw, feats) ->         
        let sw_string = Int64.to_string sw in  
        let notifs = map (fun portid -> {typeid="switch_port"; 
                                          values=construct_map [("sw", sw_string); ("pt", (Int32.to_string portid))] }) feats.ports in
        printf "SWITCH %Ld connected. Flowlog events triggered: %s\n%!" sw (String.concat ", " (map string_of_event notifs));
        List.iter (fun notif -> respond_to_notification p notif) notifs;
        trigger_policy_recreation_thunk()

      | SwitchDown(swid) -> 
        printf "WARNING: switch down. Currently unsupported. TODO: create new event type in Flowlog.\n%!";
        ()
    and

    switch_event_handler_policy = HandleSwitchEvent(switch_event_handler) 
    and

    (* the thunk needs to know the pkt callback, the pkt callback invokes the thunk. so need "and" *)
    trigger_policy_recreation_thunk (): unit = 
      if not notables then
      begin
        (* Update the policy *)
        let (newfwdpol, newnotifpol) = program_to_netcore p updateFromPacket in
        printf "NEW FWD policy: %s\n%!" (NetCore_Pretty.string_of_pol newfwdpol);
        printf "NEW NOTIF policy: %s\n%!" (NetCore_Pretty.string_of_pol newnotifpol);
        let newpol = Union(Union(newfwdpol, newnotifpol), switch_event_handler_policy) in      
        push (Some newpol);              
      end
      else
        if notables then printf "\n*** FLOW TABLE COMPILATION DISABLED! ***\n%!";
        (*DO NOT CALL THIS: push None*)
    and
      
    (* The callback to be invoked when the policy says to send pkt to controller *)
    updateFromPacket (sw: switchId) (pt: port) (pkt: Packet.packet) : NetCore_Types.action =    
      (* Update the policy via the push function *)
      printf "Packet in on switch %Ld.\n%s\n%!" sw (Packet.to_string pkt);
      counter_inc_pkt := !counter_inc_pkt + 1;
      fwd_actions := []; (* populated by things respond_to_notification calls *)

      (* Parse the packet and send it to XSB. Deal with the results *)
      let notif = (pkt_to_event sw pt pkt) in           
        printf "... notif: %s\n%!" (string_of_event notif);
        respond_to_notification p notif;      
        trigger_policy_recreation_thunk();
        (* This callback returns an action set to Frenetic. *) 
        !fwd_actions in

    if not notables then
    begin
      let (initfwdpol, initnotifpol) = program_to_netcore p updateFromPacket in
      printf "INITIAL FWD policy is:\n%s\n%!" (NetCore_Pretty.string_of_pol initfwdpol);
      printf "INITIAL NOTIF policy is:\n%s\n%!" (NetCore_Pretty.string_of_pol initnotifpol);
      let initpol = Union(Union(initfwdpol, initnotifpol), switch_event_handler_policy) in          
      (* cargo-cult hacking invocation. why call this? *)
      (trigger_policy_recreation_thunk, NetCore_Stream.from_stream initpol policies)
    end else begin      
      let initpol = Union(switch_event_handler_policy, Action([ControllerAction(updateFromPacket)])) in
        (trigger_policy_recreation_thunk, NetCore_Stream.from_stream initpol policies)
    end;;


