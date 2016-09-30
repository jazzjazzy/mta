-module(getmxrr).
-export([lookup/1]).
%-compile(export_all).


lookup(DomainName) ->
	case (getMXrr(DomainName)) of 
		{error,nxdomain} ->  {ok, DomainName};
		{error,Reason} -> throw({error, 700, Reason});
	    ELSE -> checkDomain(ELSE)
	end.

getMXrr([])->throw({error, 701, "No Domain to find"});
getMXrr(D)->
	 case inet_res:nslookup(D, 1, mx) of
		 {ok, {dns_rec, _, _, ListMX, _, _}} ->
			L = qsort(ListMX),
	 		G = lists:map(fun({dns_rr,_,_,_,_,_,P1,_,_,_})->P1 end,L),
	 		G;
		 {error, Reason} -> {error, Reason}
	 end.

checkDomain([])->throw({error, 703, "No List of MX record to find"});
checkDomain([{_,Domain}|T])->
    L = inet_res:lookup(Domain,in, a),
	case L of
		 [] -> checkDomain(T);
		 _ELSE -> L
	end,
	{ok, Domain}.
checkDomain([{_,Domain}|T], Type)->
    L = inet_res:lookup(Domain,in, T),
	case L of
		 [] -> checkDomain(T, Type);
		 _ELSE -> L
	end,
	{ok, Domain}.
checkDomain([{_,Domain}|T], Type, Class)->
    L = inet_res:lookup(Domain,Class, T),
	case L of
		 [] -> checkDomain(T, Type, Class);
		 _ELSE -> L
	end,
	{ok, Domain}.

%% Sort 
qsort([]) -> [];
qsort([Pivot|T]) ->
	qsort([X || X <- T, X < Pivot])
	++ [Pivot] ++
	qsort([X || X <- T, X >= Pivot]).
