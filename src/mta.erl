-module(mta).
-export([start/0, sender/2]).
-import(getmxrr, [lookup/1] ).
-import(tools, [gsub/3, generate/0, sleep/1] ).
-define(PORTNO, 25). 
-define(TIMEOUT, 30000).
-define(HOST, "localhost").
-define(SENDER, "jason@localhost").
%-define(HOST, "mail.internode.on.net").
%-define(SENDER, "jason@lexxcom.com").

start()->
	spawn(fun loop/0).

sender(Pid, What) ->
	rpc(Pid, What).

rpc(Pid, Request) ->
	Pid ! {self(), Request},
	receive
		{Pid, Response} -> Response
    end.

loop() ->
	receive
		{From, {send, Email,Subject, Message, Text}}->
	 		From ! {self(), send( Email,Subject, Message, Text)},
			loop();
	 	Oops-> exit(Oops)
	end.


send(Email, Subject, Message, Text) -> 
	try
		{domain, Domain} = email(Email),%break the user from the domain 
		{ok, EmailConnect} = getmxrr:lookup(Domain),%get the email server from the MX record
		io:format("getting connection from server ~n"),
		Sock = case gen_tcp:connect(EmailConnect, ?PORTNO, [list, {packet, 0},{active, false}], ?TIMEOUT) of % connect to the mail server
			{ok, S} -> S;
		    {error, timeout} -> throw({error, 710, "Connection to mail server timed out"});
			{error, Reason} -> throw({error, 711, Reason})
		end,
		
		sleep(1000), % need to sleep for a second for sendmail, if we push ahead to fast sendmail will reject  
	
		sendRecvMessage({Sock}),
		sendRecvMessage({Sock, "MAIL FROM:<"++?SENDER++">\r\n", 250}), % had to remove XVERP as it will not work on local server
		sendRecvMessage({Sock, "RCPT TO:<"++Email++">\r\n", 250}),
		sendRecvMessage({Sock, "DATA\r\n", 354}),
		sendRecvMessage({Sock, sendData(Email, Subject, Message, Text), 250}),
		gen_tcp:close(Sock)
	catch
		throw:X -> throw(X);
		exit:X  -> throw(X)
	end.

email(Email) -> 
	L=string:tokens(Email, "@"),
	Domain = erlang:list_to_atom(lists:last(L)),
    {domain, Domain}. 

recv_message(Sock)->
	case gen_tcp:recv(Sock, 0, ?TIMEOUT) of
		{ok, Bin} ->
			Bin;
		{error, timeout} ->
			throw({error, 730, "Recv message timed out"});
		{error, Reason} ->
			exit({"EXIT",Sock,Reason})
	end.

sendData(Recipient, Subject, Message, Text)->
	
	ContentPart = generate(),
	Headers = headerLine("Date", httpd_util:rfc1123_date(erlang:universaltime()) ++" -1000 (UTC)") ++ %% THIS IS NOT RIGHT FIXIT!!!
	headerLine("Return-Path",?SENDER) ++
	headerLine("To", Recipient)++
	headerLine("From", ?SENDER )++
	headerLine("Reply-to", ?SENDER)++
	headerLine("Subject", Subject)++
	headerLine("Message-ID", "<"++tools:generate()++">@"++?HOST)++
	headerLine("X-Priority", "3") ++
	headerLine("MIME-Version","1.0")++ 
	headerLine("Content-Type","multipart/alternative; \n\t boundary=\"----=_Part_"++ContentPart)++
	headerLine("X-Mailer", "Pigeon MTA test Beta v0.1"),
	
	Head = gsub(gsub(Headers, "\r\n","\n"), "\r", "\n"),
	
	TxtMessage = text(Text, ContentPart),
	HtmlMessage = html(Message, ContentPart),
	
	Head++TxtMessage++HtmlMessage++"\r\n.\r\n".

html(Message, ContentPart)->
	CleanedStr = gsub(gsub(gsub(Message, "\r\n"," "), "\r", " "),"\n", " "), %% remove all breaks to make a single string	
	contentType(ContentPart, "text/html", "UTF-8","quoted-printable","html-body")++
	gsubLength(CleanedStr,"=\n",77)++"\n------=_Part_"++ContentPart++"--". 

text(Message, ContentPart)->
	"\r\n\r\n"++contentType(ContentPart, "text/plain", "UTF-8","7bit","text-body")++Message++"\n\n".

contentType(ContentPart, Mime, Charset, Encoding, ContentId)->
	"------=_Part_"++ContentPart++
	"\nContent-Type: "++Mime++";charset="++Charset++
	"\nContent-Transfer-Encoding: "++Encoding++
	"\nContent-ID: "++ContentId++"\n\n".

headerLine(Header, Value)->
    Header++": "++Value++"\n".

sendRecvMessage({Sock})->
	gen_tcp:send(Sock, "HELO "++?HOST++"\r\n"),
	  
	Recv = recv_message(Sock),
	CodeRecv = element(1, string:to_integer(string:substr(Recv, 1, 3))),
	
	case CodeRecv of
		554 -> 	io:format("~p ~p Status ~p~n", [CodeRecv , "HELO "++?HOST++"\r\n", Recv]),
			
				gen_tcp:send(Sock, "EHLO "++?HOST++"\r\n"),
				
			 	Recv2 = recv_message(Sock),
			  	CodeRecv2 = element(1, string:to_integer(string:substr(Recv2, 1, 3))),
				case CodeRecv2 of
						
					CodeRecv2 when CodeRecv2 >= 500 -> exit({'EXIT',Sock, "Server not excepting Hello connection" });
					
					_Other -> io:format("~p ~p~n", [CodeRecv2,"EHLO "++?HOST++"\r\n"]),
								  {ok, CodeRecv2}
				 end;
		
		Code when Code >= 500 -> exit({'EXIT',Sock, "Server not excepting Hello connection" });
	    
		_Other -> 	io:format("~p ~p~n", [CodeRecv, "HELO "++?HOST++"\r\n"]),
					{ok, CodeRecv}
	 end;

sendRecvMessage({Sock, Message, Code}) ->
	gen_tcp:send(Sock, Message),
	
	Recv = recv_message(Sock),
	CodeRecv = element(1, string:to_integer(string:substr(Recv, 1, 3))),
	if 
		CodeRecv >=  500   -> io:format("~p ~p Status ~p~n", [CodeRecv, Message, Recv]),
							  throw({error, CodeRecv, Recv});
		CodeRecv =/= Code  -> io:format("~p ~p Status ~p~n", [CodeRecv, Message, Recv]),
							  {error, CodeRecv};
		CodeRecv =:= Code  -> io:format("~p ~p~n", [CodeRecv, Recv]),
							  {ok, CodeRecv}
	end. 

subLength(Str,New, Length) ->

   Lstr = string:len(Str),
   Pos  = string:rstr(Str,New) + Length,
   if 
      Pos =:= 0 -> 
                   Str;
	  Pos > Lstr -> 
		  			Str;
      true      ->
           LeftPart = string:left(Str,Pos),
           RitePart = string:right(Str,Lstr-1-Pos),
           string:concat(string:concat(LeftPart,New),RitePart)
	end.

gsubLength(Str,New, Length) ->
	Acc = subLength(Str,New,Length),
	substLength(Acc,New,Length,Str).

substLength(Str,_New,_Length, Str) -> Str;
substLength(Acc, New,Length,_Str) ->
	Acc1 = subLength(Acc,New,Length),
	substLength(Acc1,New,Length,Acc).


