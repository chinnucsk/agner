%% -*- Mode: Erlang; tab-width: 4 -*-
-module(agner_main).
-export([main/1]).
-include_lib("kernel/include/file.hrl").
%% internal
-export([handle_command/2]).

start() ->
    agner:start().

stop() ->
    error_logger:delete_report_handler(error_logger_tty_h),
    agner:stop().

arg_proplist() ->
	[{"version",
      {version,
       "Agner version",
       []}},
     {"help",
      {help,
       "Use agner help <command>",
       [{command, undefined, undefined, string, "Command"}]}},
     {"spec",
	  {spec,
	   "Output the specification of a package",
	   [
		{package, undefined, undefined, string, "Package name"},
		{browser, $b, "browser", boolean, "Show specification in the browser"},
		{homepage, $h, "homepage", boolean, "Show package homepage in the browser"},
		{version, $v, "version", {string, "@master"}, "Version"},
        {property, $p, "property", string, "Particular property to render instead of a full spec"},
        {spec, $s, "spec-file", string, "Use local specification file"}
	   ]}},
	 {"versions",
	  {versions,
	  "Show the available releases and flavours of a package",
	   [
		{package, undefined, undefined, string, "Package name"},
        {no_flavours, undefined, "no-flavours", {boolean, false}, "Don't show flavour versions"},
        {no_releases, undefined, "no-releases", {boolean, false}, "Don't show release versions"}
	   ]}},
	 {"list",
	  {list,
	   "List packages on stdout",
	   [
		{descriptions, $d, "descriptions", {boolean, false}, "Show package descriptions"},
		{properties, $p, "properties", string, "Comma-separated list of properties to show"},
        {search, $s, "search", string, "Keyword to search"}
	   ]}},
     {"search",
      {search,
       "Search packages",
       [
        {search, undefined, undefined, string, "Keyword to search"},
		{descriptions, $d, "descriptions", {boolean, false}, "Show package descriptions"},
		{properties, $p, "properties", string, "Comma-separated list of properties to show"}
       ]}},
	 {"fetch",
	  {fetch,
	   "Download a package",
	   [
		{package, undefined, undefined, string, "Package name"},
		{directory, undefined, undefined, string, "Directory to check package out to"},
		{version, $v, "version", {string, "@master"}, "Version"},
        {build, $b, "build", {boolean, false}, "Build fetched package"},
        {addpath, $a, "add-path", {boolean, false}, "Add path to compiled package to .erlang"},
        {install, $i, "install", {boolean, false}, "Install package (if install_command is available)"},
        {spec, $s, "spec-file", string, "Use local specification file"}
	   ]}},
     {"install",
      {install,
       "Install a package",
	   [
		{package, undefined, undefined, string, "Package name"},
		{version, $v, "version", {string, "@master"}, "Version"},
        {spec, $s, "spec-file", string, "Use local specification file"}
	   ]}},
     {"uninstall",
      {uninstall,
       "Uninstall previously installed package",
	   [
		{package, undefined, undefined, string, "Package name"},
		{version, $v, "version", {string, "@master"}, "Version"},
        {spec, $s, "spec-file", string, "Use local specification file"}
	   ]}},
     {"prefix",
      {prefix,
       "Shows location where particular package is installed",
	   [
		{package, undefined, undefined, string, "Package name"},
		{version, $v, "version", {string, "@master"}, "Version"}
	   ]}},
     {"build",
      {build,
       "Build a package",
	   [
		{package, undefined, undefined, string, "Package name"},
		{version, $v, "version", {string, "@master"}, "Version"},
        {spec, $s, "spec-file", string, "Use local specification file"},
        {package_path, undefined, "package-path", string, "Path to the package repo contents (used in conjunction with --spec-file only, defaults to '.')"},
        {addpath, $a, "add-path", {boolean, false}, "Add path to compiled package to .erlang"},
        {install, $i, "install", {boolean, false}, "Install package (if install_command is available)"},
		{directory, undefined, undefined, string, "Directory to check package out to"}
	   ]}},      
     {"create",
      {create,
       "Create new .agner repository",
       [
        {package, undefined, undefined, string, "Package name"},
        {github_account, undefined, "github-account",{string, "agner"}, "GitHub account to set as origin"}
       ]}},
	 {"verify",
	  {verify,
	   "Verify the integrity of an .agner configuration file",
	   [
		{spec, undefined, undefined, {string, "agner.config"}, "Specification file (agner.config by default)"}
	   ]}},
     {"config",
      {config,
       "Show Agner's environmental configuration",
       [
        {variable, undefined, undefined, string, "Variable name, omit to list all of them"}
       ]}}].
       

command_descriptions() ->
	[{Cmd, Desc} || {Cmd, {_Atom, Desc, _Opts}} <- arg_proplist()].

parse_args([Arg|Args]) ->
	case proplists:get_value(Arg, arg_proplist()) of
		undefined -> no_parse;
		{A, _Desc, OptSpec} -> {arg, A, Args, OptSpec}
	end;
parse_args(_) -> no_parse.

usage() ->
    OptSpec = [
               {command, undefined, undefined, string, "Command to be executed (e.g. spec)"}
               ],
	io:format("Agner: ~s~n", [agner_backcronym()]),
    getopt:usage(OptSpec, "agner", "[options ...]"),
	io:format("Valid commands are:~n", []),
	[io:format("   ~-10s ~s~n", [Cmd, Desc]) || {Cmd, Desc} <- command_descriptions()].

main(Args) ->
    os:putenv("AGNER", filename:absname(escript:script_name())),
	case parse_args(Args) of
		{arg, Command, ExtraArgs, OptSpec} ->
			case getopt:parse(OptSpec, ExtraArgs) of
				{ok, {Opts, _}} ->
					start(),
					Result = (catch handle_command(Command, Opts)),
                    case Result of
                        {'EXIT', {{agner_failure, Reason},_}} ->
                            io:format("ERROR: ~s~n",[Reason]);
                        {'EXIT', Error} ->
                            io:format("FAILURE: ~p~n",[Error]);
                        _ ->
                            ignore
                    end,
					stop();
			    {error, {missing_option_arg, Arg}} ->
					io:format("Error: Missing option argument for '~p'~n", [Arg])
			end;
		no_parse ->
			usage()
	end.

handle_command(help, []) ->
    usage();
handle_command(help, Opts) ->
    case proplists:get_value(command, Opts) of
        undefined ->
            usage();
        Command ->
            case proplists:get_value(Command, arg_proplist()) of
                {_Atom, _Desc, Opts1} ->
                    getopt:usage(Opts1, "agner " ++ Command);
                undefined ->
                    io:format("No such command: ~s~n", [Command])
            end
    end;

handle_command(spec, Opts) ->
    case proplists:get_value(package, Opts) of
        undefined ->
            io:format("ERROR: Package name required.~n");
        Package ->
            Version = proplists:get_value(version, Opts),
            case proplists:get_value(browser, Opts) of
                true ->
                    agner_utils:launch_browser(agner:spec_url(Package, Version));
                _ ->
                    ignore
            end,
            Spec = 
                case proplists:get_value(spec, Opts) of
                    undefined ->
                        agner:spec(Package, Version);
                    File ->
                        {ok, T} = file:consult(File),
                        T
                end,
            case proplists:get_value(homepage, Opts) of
                true ->
                    agner_utils:launch_browser(proplists:get_value(homepage, Spec, "http://google.com/#q=" ++ Package));
                _ ->
                    ignore
            end,
            case proplists:get_value(property, Opts) of
                undefined ->
                    lists:foreach(fun(Property) ->
                                          io:format("~p.~n",[Property])
                                  end, Spec);
                Property ->
                    io:format("~s~n",[agner_spec:property_to_list(lists:keyfind(list_to_atom(Property), 1, Spec))])
            end
    end;

handle_command(versions, Opts) ->
    case proplists:get_value(package, Opts) of
        undefined ->
            io:format("ERROR: Package name required.~n");
        Package ->
            NoFlavours = proplists:get_value(no_flavours, Opts),
            NoReleases = proplists:get_value(no_releases, Opts),
            io:format("~s",[lists:usort(plists:map(fun ({flavour, _} = Version) when not NoFlavours ->
                                                           io_lib:format("~s~n",[agner_spec:version_to_list(Version)]);
                                                       ({release, _} = Version) when not NoReleases ->
                                                           io_lib:format("~s~n",[agner_spec:version_to_list(Version)]);
                                                       (_) ->
                                                           ""
                                                   end,
                                                   agner:versions(Package)))])
    end;

handle_command(search, Opts) ->
    handle_command(list, Opts);

handle_command(list, Opts) ->
    ShowDescriptions = proplists:get_value(descriptions, Opts),
    Search = proplists:get_value(search, Opts),
    Properties = lists:map(fun list_to_atom/1, string:tokens(proplists:get_value(properties, Opts,""),",")),
    lists:foreach(fun (Name) ->
                          Spec = agner:spec(Name),
                          Searchable = string:to_lower(lists:flatten([Name,proplists:get_value(description,Spec,[])|proplists:get_value(keywords,Spec,[])])),
                          Show = 
                              case Search of
                                  undefined ->
                                      true;
                                  [_|_] ->
                                      string:rstr(Searchable, string:to_lower(Search)) > 0
                              end,
                          case Show of
                              true ->
                                  case ShowDescriptions of
                                      true ->
                                          io:format("~-40s ~s",[Name, proplists:get_value(description, Spec)]);
                                      false ->
                                          io:format("~s",[Name])
                                  end,
                                  case Properties of
                                      [] ->
                                          ignore;
                                      [_|_] ->
                                          lists:foreach(fun (Prop) ->
                                                                case lists:keyfind(Prop, 1, Spec) of
                                                                    false ->
                                                                        ignore;
                                                                    T ->
                                                                        Val = list_to_tuple(tl(tuple_to_list(T))),
                                                                        io:format(" | ~s: ~p",[Prop,
                                                                                               Val])
                                                                end
                                                        end, Properties)
                                  end,
                                  io:format("~n");
                              false ->
                                  ok
                          end
                  end,agner:index());

handle_command(prefix, Opts) ->
    case proplists:get_value(package, Opts) of
        undefined ->
            io:format("ERROR: Package name required.~n");
        Package ->
            Version = proplists:get_value(version, Opts),
            InstallPrefix = filename:join([os:getenv("AGNER_PREFIX"),"packages",Package ++ "-" ++ Version]),
            case filelib:is_dir(InstallPrefix) of
                true ->
                    io:format("~s~n",[InstallPrefix]);
                false ->
                    ignore
            end
    end;

handle_command(uninstall, Opts) ->
    case proplists:get_value(package, Opts) of
        undefined ->
            io:format("ERROR: Package name required.~n");
        Package ->
            Version = proplists:get_value(version, Opts),
            InstallPrefix = filename:join([os:getenv("AGNER_PREFIX"),"packages",Package ++ "-" ++ Version]),
            case filelib:is_dir(InstallPrefix) of
                true ->
                    io:format("Uninstalling...~n"),
                    Spec = 
                        case proplists:get_value(spec, Opts) of
                            undefined ->
                                agner:spec(Package, Version);
                            File ->
                        {ok, T} = file:consult(File),
                                T
                        end,
                    os:cmd("rm -rf " ++ InstallPrefix),
                    case proplists:get_value(bin_files, Spec) of
                        undefined ->
                            ignore;
                        Files ->
                            lists:foreach(fun (File) ->
                                                  Symlink = filename:join(os:getenv("AGNER_BIN"),filename:basename(File)),
                                                  file:delete(Symlink)
                                          end, Files)
                    end;
                false ->
                    io:format("ERROR: This package hasn't been installed~n")
            end
    end;

handle_command(install, Opts) ->
    TmpFile = temp_name(),
    handle_command(fetch, [{build, true},{directory, TmpFile},{install, true},{addpath, false}|Opts]),
    os:cmd("rm -rf " ++ TmpFile);

handle_command(build, Opts) ->
    handle_command(fetch, [{build, true}|Opts]);

handle_command(fetch, Opts) ->
    process_flag(trap_exit, true),
    error_logger:delete_report_handler(error_logger_tty_h),
    {ok, Pid} = agner_fetch:start_link(Opts),
    receive
        {'EXIT', Pid, shutdown} -> 
            ok;
        {'EXIT', Pid, {error, Errors}} when is_list(Errors) ->
            [ format_error(Error) || Error <- Errors ];
        {'EXIT', Pid, {error, Error}} ->
            format_error(Error);
        Other ->
            io:format("FAILURE: ~p~n",[Other])
    end;

handle_command(create, Opts) ->
    case proplists:get_value(package, Opts) of
        undefined ->
            io:format("ERROR: Package name required.~n");
        Package ->
            Dir = filename:absname(Package ++ ".agner"),
            ClonePort = agner_download:git(["clone","-q","https://github.com/agner/agner.template.git",Dir]),
            agner_download:process_port(ClonePort, fun() ->
                                                           agner_download:git(["config","remote.origin.url","git@github.com:" ++ proplists:get_value(github_account, Opts) ++ "/" ++ Package ++ ".agner.git"],[{cd, Dir}])
                                                   end)
    end;

handle_command(verify, Opts) ->
    SpecFile = proplists:get_value(spec, Opts),
    case file:consult(SpecFile) of
        {error, Reason} ->
            io:format("ERROR: Can't read ~s: ~p~n",[SpecFile, Reason]);
        {ok, Spec} ->
            URL = proplists:get_value(url, Spec),
			TmpFile = temp_name(),
            case (catch agner_download:fetch(Spec,TmpFile)) of
                ok ->
                    io:format("~nPASSED~n");
                {'EXIT', {Reason, _}} ->
                    io:format("~nEROR: Can't fetch ~p: ~p~n",[URL, Reason]);
                {error, Reason} ->
                    io:format("~nEROR: Can't fetch ~p: ~p~n",[URL, Reason])
            end,
            os:cmd("rm -rf " ++ TmpFile)
    end;

handle_command(version, _) ->
    {agner,_,Version} = lists:keyfind(agner,1,application:which_applications()),
    io:format("~s~n",[Version]);

handle_command(config, []) ->
    io:format("prefix="), handle_command(config,[{variable, "prefix"}]),
    io:format("bin="), handle_command(config,[{variable, "bin"}]);
handle_command(config, [{variable, "prefix"}]) ->
    io:format("~s~n",[os:getenv("AGNER_PREFIX")]);
handle_command(config, [{variable, "bin"}]) ->
    io:format("~s~n",[os:getenv("AGNER_BIN")]).
  
%%%

format_error({_, Error}) when is_list(Error) ->
    io:format("ERROR: ~s~n",[Error]).

%%%%

temp_name() ->
	%% Yes, the temp_name function lives in the test_server, go figure!
	test_server:temp_name("/tmp/agner").

agner_backcronym() ->
	random:seed(erlang:now()),
	N = random:uniform(length(backcronyms())),
	lists:nth(N, backcronyms()).

backcronyms() ->
	["A Giant Nebula of Erlang Repositories",
	 "A Giant Network of Erlang Repositories",
	 "A Glorified Nest of Erlang Repositories",
	 "A Google of Nerdy Erlang Researchers",
	 "A Groovy Nirvana of Erlang Research",
	 "Alpha Grade Neurogenic Erlang Recoder",
	 "Altered Gravity Nebula of Erlang Results",
	 "Advancing the Galaxy of Native Erlang Resources",
	 "Absolutely the Greatest of Naked Erlang Results",
	 "Altering the Genetics of Native Erlang Roaches",
	 "Abducting the Greatest of Nascent Erlang Repositories",
	 "Algebraic Grouping of Net Erlang Returns",
	 "Able Giraffes Needed for Erlang Research",
	 "All Gurus Needed for Erlang Recreation",
	 "A Group of New Erlang Recruits",
	 "A Geiger for Nuclear Erlang Research",
	 "All Grapplers Near Erlang Retreat",
	 "A Grenade Near Erlangs Radius",
	 "As Github Narrows Erlang Requests",
	 "Alcoholic Github Negates Erlang Redundancy",
	 "Abuse Grows Now Erlang's Relieved",
	 "A Giddy Nerd on Erlang Retreat",
	 "Alcohol, Gin, and a Numb Erlang Result",
	 "Ability Gains Net Erlang Returns",
	 "Awesome Group; Now Enjoy and Relax",
	 "Army Generals, Never Enjoy Rest",
	 "Acknowledge Gerbils in Nuclear Erlang Reactor",
	 "A Gross Nephew Eats Raccoons",
	 "A Gorilla Never Eats Rabbits",
	 "A Grappler Needs Exceptional Restraint",
	 "A Graph Near Equal Required",
	 "All Garbage Near Erlang RELOCATE!",
	 "All Graduates Need Erlang Résumés",
	 "Automatically Guillotine Non-Erlang Responsibilities",
	 "Al Gore Needs Environmental Repairs",
	 "A Genius Needed to Evolve Relativity",
	 "A Gentleman Never Encourages Rebuilds",
	 "Awk Greets New Erlang Repositories",
	 "All Grain Nutrition Except Rice",
	 "A Gentler Newer Erlang Rebar",
	 "Accidents Get Nearly Epic Repercussions",
	 "All Gravity Near Erlang Restored",
	 "Artificial Gravity Nacelle Enhanced Rockets",
	 "All Grinning Not Erlang Related",
	 "A Game Network Echo Responder",
	 "Al Green Needs Ear Reception",
	 "Auto Guided Nuclear Enhanced Rockets",
	 "All Grid Network Engineers Recalled",
	 "A Growing Need for Einstein's Return",
	 "A Guru Needs Erlang's Results",
	 "Apple Gravy Nearly Enhances Ravioli",
	 "A Growing Need to Edit Reports",
	 "A Growl Nearly Escaped Release",
	 "A Good Nurse Earns Respect",
	 "Addicted Gamblers Never Enjoy Returns",
	 "A Game Needing Enhanced Reflexes",
	 "Agner Got New Erlang Releases",
	 "A Great Nocturnal Erlang Release",
	 "A Grave Never Entertains Relatives",
	 "A Grenade Near Enemies Revenges",
	 "Accidently Gored Now Entrails Released",
	 "Asimov Grasped Neurally Enhanced Robots",
	 "Anti Gravity Networks Effect Range",
	 "Agner Guarantees Near Erlang Recreation",
	 "Agner Gains Ninja Erlang Reputation",
	 "Agner Gives Ninja Erlang Reflexes"].

