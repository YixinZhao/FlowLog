(*
 Autogenerated by Thrift Compiler (0.8.0)

 DO NOT EDIT UNLESS YOU ARE SURE YOU KNOW WHAT YOU ARE DOING
*)

open Thrift
class notification =
object (self)
  val mutable _notificationType : string option = None
  method get_notificationType = _notificationType
  method grab_notificationType = match _notificationType with None->raise (Field_empty "notification.notificationType") | Some _x0 -> _x0
  method set_notificationType _x0 = _notificationType <- Some _x0
  method unset_notificationType = _notificationType <- None
  method reset_notificationType = _notificationType <- None

  val mutable _values : (string,string) Hashtbl.t option = None
  method get_values = _values
  method grab_values = match _values with None->raise (Field_empty "notification.values") | Some _x1 -> _x1
  method set_values _x1 = _values <- Some _x1
  method unset_values = _values <- None
  method reset_values = _values <- None

  method copy =
      let _new = Oo.copy self in
      if _values <> None then
        _new#set_values (Hashtbl.copy self#grab_values);
    _new
  method write (oprot : Protocol.t) =
    oprot#writeStructBegin "Notification";
    (match _notificationType with 
    | None -> raise (Field_empty "notification._notificationType")
    | Some _v -> 
      oprot#writeFieldBegin("notificationType",Protocol.T_STRING,1);
      oprot#writeString(_v);
      oprot#writeFieldEnd
    );
    (match _values with 
    | None -> raise (Field_empty "notification._values")
    | Some _v -> 
      oprot#writeFieldBegin("values",Protocol.T_MAP,2);
      oprot#writeMapBegin(Protocol.T_STRING,Protocol.T_STRING,Hashtbl.length _v);
      Hashtbl.iter (fun _kiter4 -> fun _viter5 -> 
        oprot#writeString(_kiter4);
        oprot#writeString(_viter5);
      ) _v;
      oprot#writeMapEnd;
      oprot#writeFieldEnd
    );
    oprot#writeFieldStop;
    oprot#writeStructEnd
end
let rec read_notification (iprot : Protocol.t) =
  let _str6 = new notification in
    ignore(iprot#readStructBegin);
    (try while true do
        let (_,_t7,_id8) = iprot#readFieldBegin in
        if _t7 = Protocol.T_STOP then
          raise Break
        else ();
        (match _id8 with 
          | 1 -> (if _t7 = Protocol.T_STRING then
              _str6#set_notificationType iprot#readString
            else
              iprot#skip _t7)
          | 2 -> (if _t7 = Protocol.T_MAP then
              _str6#set_values 
                (let (_ktype10,_vtype11,_size9) = iprot#readMapBegin in
                let _con13 = Hashtbl.create _size9 in
                  for i = 1 to _size9 do
                    let _k = iprot#readString in
                    let _v = iprot#readString in
                      Hashtbl.add _con13 _k _v
                  done; iprot#readMapEnd; _con13)
            else
              iprot#skip _t7)
          | _ -> iprot#skip _t7);
        iprot#readFieldEnd;
      done; ()
    with Break -> ());
    iprot#readStructEnd;
    _str6

class query =
object (self)
  val mutable _relName : string option = None
  method get_relName = _relName
  method grab_relName = match _relName with None->raise (Field_empty "query.relName") | Some _x15 -> _x15
  method set_relName _x15 = _relName <- Some _x15
  method unset_relName = _relName <- None
  method reset_relName = _relName <- None

  val mutable _arguments : string list option = None
  method get_arguments = _arguments
  method grab_arguments = match _arguments with None->raise (Field_empty "query.arguments") | Some _x16 -> _x16
  method set_arguments _x16 = _arguments <- Some _x16
  method unset_arguments = _arguments <- None
  method reset_arguments = _arguments <- None

  method copy =
      let _new = Oo.copy self in
    _new
  method write (oprot : Protocol.t) =
    oprot#writeStructBegin "Query";
    (match _relName with 
    | None -> raise (Field_empty "query._relName")
    | Some _v -> 
      oprot#writeFieldBegin("relName",Protocol.T_STRING,1);
      oprot#writeString(_v);
      oprot#writeFieldEnd
    );
    (match _arguments with 
    | None -> raise (Field_empty "query._arguments")
    | Some _v -> 
      oprot#writeFieldBegin("arguments",Protocol.T_LIST,2);
      oprot#writeListBegin(Protocol.T_STRING,List.length _v);
      List.iter (fun _iter19 ->         oprot#writeString(_iter19);
      ) _v;
      oprot#writeListEnd;
      oprot#writeFieldEnd
    );
    oprot#writeFieldStop;
    oprot#writeStructEnd
end
let rec read_query (iprot : Protocol.t) =
  let _str20 = new query in
    ignore(iprot#readStructBegin);
    (try while true do
        let (_,_t21,_id22) = iprot#readFieldBegin in
        if _t21 = Protocol.T_STOP then
          raise Break
        else ();
        (match _id22 with 
          | 1 -> (if _t21 = Protocol.T_STRING then
              _str20#set_relName iprot#readString
            else
              iprot#skip _t21)
          | 2 -> (if _t21 = Protocol.T_LIST then
              _str20#set_arguments 
                (let (_etype26,_size23) = iprot#readListBegin in
                  let _con27 = (Array.to_list (Array.init _size23 (fun _ -> iprot#readString))) in
                    iprot#readListEnd; _con27)
            else
              iprot#skip _t21)
          | _ -> iprot#skip _t21);
        iprot#readFieldEnd;
      done; ()
    with Break -> ());
    iprot#readStructEnd;
    _str20

class queryReply =
object (self)
  val mutable _result : (string list,bool) Hashtbl.t option = None
  method get_result = _result
  method grab_result = match _result with None->raise (Field_empty "queryReply.result") | Some _x29 -> _x29
  method set_result _x29 = _result <- Some _x29
  method unset_result = _result <- None
  method reset_result = _result <- None

  val mutable _exception_code : string option = None
  method get_exception_code = _exception_code
  method grab_exception_code = match _exception_code with None->raise (Field_empty "queryReply.exception_code") | Some _x30 -> _x30
  method set_exception_code _x30 = _exception_code <- Some _x30
  method unset_exception_code = _exception_code <- None
  method reset_exception_code = _exception_code <- None

  val mutable _exception_message : string option = None
  method get_exception_message = _exception_message
  method grab_exception_message = match _exception_message with None->raise (Field_empty "queryReply.exception_message") | Some _x31 -> _x31
  method set_exception_message _x31 = _exception_message <- Some _x31
  method unset_exception_message = _exception_message <- None
  method reset_exception_message = _exception_message <- None

  method copy =
      let _new = Oo.copy self in
      if _result <> None then
        _new#set_result (Hashtbl.copy self#grab_result);
    _new
  method write (oprot : Protocol.t) =
    oprot#writeStructBegin "QueryReply";
    (match _result with 
    | None -> raise (Field_empty "queryReply._result")
    | Some _v -> 
      oprot#writeFieldBegin("result",Protocol.T_SET,1);
      oprot#writeSetBegin(Protocol.T_LIST,Hashtbl.length _v);
      Hashtbl.iter (fun _iter34 -> fun _ ->         oprot#writeListBegin(Protocol.T_STRING,List.length _iter34);
        List.iter (fun _iter35 ->           oprot#writeString(_iter35);
        ) _iter34;
        oprot#writeListEnd;
      ) _v;
      oprot#writeSetEnd;
      oprot#writeFieldEnd
    );
    (match _exception_code with None -> () | Some _v -> 
      oprot#writeFieldBegin("exception_code",Protocol.T_STRING,2);
      oprot#writeString(_v);
      oprot#writeFieldEnd
    );
    (match _exception_message with None -> () | Some _v -> 
      oprot#writeFieldBegin("exception_message",Protocol.T_STRING,3);
      oprot#writeString(_v);
      oprot#writeFieldEnd
    );
    oprot#writeFieldStop;
    oprot#writeStructEnd
end
let rec read_queryReply (iprot : Protocol.t) =
  let _str36 = new queryReply in
    ignore(iprot#readStructBegin);
    (try while true do
        let (_,_t37,_id38) = iprot#readFieldBegin in
        if _t37 = Protocol.T_STOP then
          raise Break
        else ();
        (match _id38 with 
          | 1 -> (if _t37 = Protocol.T_SET then
              _str36#set_result 
                (let (_etype42,_size39) = iprot#readSetBegin in
                let _con43 = Hashtbl.create _size39 in
                  for i = 1 to _size39 do
                    Hashtbl.add _con43 
                      (let (_etype47,_size44) = iprot#readListBegin in
                        let _con48 = (Array.to_list (Array.init _size44 (fun _ -> iprot#readString))) in
                          iprot#readListEnd; _con48) true
                  done; iprot#readSetEnd; _con43)
            else
              iprot#skip _t37)
          | 2 -> (if _t37 = Protocol.T_STRING then
              _str36#set_exception_code iprot#readString
            else
              iprot#skip _t37)
          | 3 -> (if _t37 = Protocol.T_STRING then
              _str36#set_exception_message iprot#readString
            else
              iprot#skip _t37)
          | _ -> iprot#skip _t37);
        iprot#readFieldEnd;
      done; ()
    with Break -> ());
    iprot#readStructEnd;
    _str36

type fLValue = string

