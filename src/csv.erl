%% @author jason
%% @doc @todo Add description to email.

-module(csv).

%% ====================================================================
%% API functions
%% ====================================================================
-export([read/1]).

read(FileName)->
    case file:open(FileName, [read, raw]) of 
	{ok, Fd}->
	    readLine(Fd);
	{error, Reason}->
	    io:format(Reason)
	 end.

readLine(F)->

    case file:read_line(F) of
	{ok, Line} ->
	    readCell(Line),
	    readLine(F);
	{error, Reason} ->
	    io:format("error :~p~n" ,[Reason]);
    eof ->
	    io:format("could be end of file")
    end.
    

readCell(Line)->
   io:format(string:tokens(Line, ",")).
    


%% ====================================================================
%% Internal function
%% ====================================================================
