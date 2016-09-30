-module(tools).
-compile(export_all).

sub(Str,Old,New) ->

   Lstr = string:len(Str),
   Lold = string:len(Old),
   Pos  = string:str(Str,Old),
   if 
      Pos =:= 0 -> 
                   Str;
      true      ->
           LeftPart = string:left(Str,Pos-1),
           RitePart = string:right(Str,Lstr-Lold-Pos+1),
           string:concat(string:concat(LeftPart,New),RitePart)
   end.

gsub(Str,Old,New) ->
  Acc = sub(Str,Old,New),
  subst(Acc,Old,New,Str).

subst(Str,_Old,_New, Str) -> Str;
subst(Acc, Old, New,_Str) ->
         Acc1 = sub(Acc,Old,New),
         subst(Acc1,Old,New,Acc).

test() ->
   io:format("~p ~p ~p ~p ~p ~p ~p ~n",
     [
      "SELECT * FROM people WHERE first='John' OR last='John'" =:=
  gsub("SELECT * FROM people WHERE first=$1 OR last=$1","$1","'John'"),
      "aBc" =:= sub("abc","b","B"),
      "Abc" =:= sub("abc","a","A"),
      "abC" =:= sub("abc","c","C"),
      "aac" =:= gsub("bbc","b","a"),
      "abc" =:= gsub("abc","d","C"),
      "abc" =:= sub("abc","d","D")]).

% will generate a random 64 char string as a uuid       
generate() ->
    Now = {_, _, Micro} = now(),
    Nowish = calendar:now_to_universal_time(Now),
    Nowsecs = calendar:datetime_to_gregorian_seconds(Nowish),
    Then = calendar:datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}}),
    Prefix = io_lib:format("~14.16.0b", [(Nowsecs - Then) * 1000000 + Micro]),
	Prefix ++ to_hex(crypto:rand_bytes(9)).
 
to_hex([]) ->
    [];
to_hex(Bin) when is_binary(Bin) ->
    to_hex(binary_to_list(Bin));
to_hex([H|T]) ->
    [to_digit(H div 16), to_digit(H rem 16) | to_hex(T)].
 
to_digit(N) when N < 10 -> $0 + N;
to_digit(N) -> $a + N-10.

sleep(T) ->
		receive
		after T ->
			true
		end.
      