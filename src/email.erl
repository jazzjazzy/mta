%% @author jason
%% @doc @todo Add description to email.

-module(email).

%% ====================================================================
%% API functions
%% ====================================================================
-export([send/0]).
-include("records.hrl").
%-import(emailStr, [start/0]).
%-define(EMAIL, "fmaster@localhost").


send()->
	X=#emails{},
	pidSender(X#emails.emails, X#emails.subject,X#emails.html,X#emails.text ).

pidSender([],_Subject,_Html,_Txt)->[];
pidSender([H|T], Subject,Html,Txt)->
  	Pid = mta:start(),
	mta:sender(Pid,{send, H, Subject, Html, Txt}),
	pidSender(T, Subject,Html,Txt).

%% ====================================================================
%% Internal functions
%% ====================================================================

%% @doc a html string to test email with 
%% emailHTML()->
%% 	"<html>
%% 	<body>
%% 		<h1>This is a test</h1>
%% 		<p>this is a test of html code for yout to view</p>
%% 	</body>
%% 	</html>
%% 	".
%% 
%% %% @doc a text string to test email with 
%% emailTEXT()->
%% 	"This is a test\r\n
%% 	\tthis is a test of html code for yout to view\r\n
%% 	".
